use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use anyhow::{anyhow, Result};
use once_cell::sync::Lazy;
use russh::client;
use russh::keys::ssh_key;
use russh::ChannelMsg;
use tokio::io::AsyncWriteExt;
use tokio::runtime::{Builder, Runtime};
use tokio::sync::mpsc;
use uuid::Uuid;

use crate::frb_generated::StreamSink;

static SESSION_STORE: Lazy<Mutex<HashMap<String, SshSession>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static CONNECTION_STORE: Lazy<Mutex<HashMap<String, SshChannel>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static OUTPUT_SINK_STORE: Lazy<Mutex<HashMap<String, StreamSink<Vec<u8>>>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static SSH_CLIENT_STORE: Lazy<Mutex<HashMap<String, SshConnectionInfo>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
pub(crate) static TOKIO_RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    Builder::new_multi_thread()
        .enable_all()
        .thread_name("deepssh-russh")
        .build()
        .unwrap()
});

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SshSession {
    pub session_id: String,
    pub profile_id: String,
    pub connection_id: String,
    pub title: String,
    pub rows: u16,
    pub cols: u16,
    pub term_type: String,
}

enum SshCommand {
    Write(Vec<u8>),
    Resize(u16, u16),
    Close,
}

struct SshChannel {
    cmd_tx: mpsc::UnboundedSender<SshCommand>,
}

struct SshConnectionInfo {
    client: Arc<client::Handle<SshClientHandler>>,
    session_ids: Vec<String>,
}

#[derive(Clone)]
struct SshClientHandler;

impl client::Handler for SshClientHandler {
    type Error = anyhow::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &ssh_key::PublicKey,
    ) -> Result<bool, Self::Error> {
        Ok(true)
    }
}

fn pty_term_type(term_type: &str) -> String {
    term_type.to_string()
}

pub fn create_output_stream(session_id: String, sink: StreamSink<Vec<u8>>) {
    OUTPUT_SINK_STORE.lock().unwrap().insert(session_id, sink);
}

pub fn connect_profile(
    profile_id: String,
    title: String,
    host: String,
    port: u16,
    username: String,
    password: String,
    term_type: String,
    rows: u16,
    cols: u16,
) -> Result<SshSession> {
    let result = TOKIO_RUNTIME.block_on(async move {
        let addr = format!("{}:{}", host, port);
        let mut config = client::Config::default();
        config.nodelay = true;
        config.keepalive_interval = Some(Duration::from_secs(30));
        let config = Arc::new(config);
        let mut handle = client::connect(config, addr, SshClientHandler)
            .await
            .map_err(|e| anyhow!("SSH connect failed: {:?}", e))?;

        let auth = handle
            .authenticate_password(username, password)
            .await
            .map_err(|e| anyhow!("SSH auth failed: {:?}", e))?;
        if !auth.success() {
            return Err(anyhow!("SSH authentication failed"));
        }

        let connection_id = Uuid::new_v4().to_string();
        let channel = handle
            .channel_open_session()
            .await
            .map_err(|e| anyhow!("SSH channel creation failed: {:?}", e))?;
        let pty_term_type = pty_term_type(&term_type);
        channel
            .request_pty(true, &pty_term_type, cols as u32, rows as u32, 0, 0, &[])
            .await
            .map_err(|e| anyhow!("PTY request failed: {:?}", e))?;
        channel
            .request_shell(true)
            .await
            .map_err(|e| anyhow!("Shell start failed: {:?}", e))?;

        let session_id = Uuid::new_v4().to_string();
        let session = SshSession {
            session_id: session_id.clone(),
            profile_id,
            connection_id: connection_id.clone(),
            title,
            rows,
            cols,
            term_type,
        };
        let (cmd_tx, cmd_rx) = mpsc::unbounded_channel::<SshCommand>();
        let (read_half, write_half) = channel.split();

        SSH_CLIENT_STORE.lock().unwrap().insert(
            connection_id,
            SshConnectionInfo {
                client: Arc::new(handle),
                session_ids: vec![session_id.clone()],
            },
        );
        CONNECTION_STORE
            .lock()
            .unwrap()
            .insert(session_id.clone(), SshChannel { cmd_tx });
        SESSION_STORE
            .lock()
            .unwrap()
            .insert(session_id.clone(), session.clone());

        TOKIO_RUNTIME.spawn(run_session_loop(
            session_id.clone(),
            read_half,
            write_half,
            cmd_rx,
        ));

        Ok(session)
    });
    if let Err(error) = &result {
        crate::app_log::log_error("ssh.connect", error);
    }
    result
}

pub fn duplicate_session(session_id: String) -> Result<SshSession> {
    let result = TOKIO_RUNTIME.block_on(async move {
        let (connection_id, profile_id, title, rows, cols, term_type) = {
            let sessions = SESSION_STORE.lock().unwrap();
            let session = sessions
                .get(&session_id)
                .ok_or_else(|| anyhow!("Session not found"))?;
            (
                session.connection_id.clone(),
                session.profile_id.clone(),
                session.title.clone(),
                session.rows,
                session.cols,
                session.term_type.clone(),
            )
        };

        let client = {
            let store = SSH_CLIENT_STORE.lock().unwrap();
            let conn_info = store
                .get(&connection_id)
                .ok_or_else(|| anyhow!("Connection not found"))?;
            Arc::clone(&conn_info.client)
        };

        let channel = client
            .channel_open_session()
            .await
            .map_err(|e| anyhow!("Channel creation failed: {:?}", e))?;
        let pty_term_type = pty_term_type(&term_type);
        channel
            .request_pty(true, &pty_term_type, cols as u32, rows as u32, 0, 0, &[])
            .await
            .map_err(|e| anyhow!("PTY request failed: {:?}", e))?;
        channel
            .request_shell(true)
            .await
            .map_err(|e| anyhow!("Shell start failed: {:?}", e))?;

        let new_session_id = Uuid::new_v4().to_string();
        let session = SshSession {
            session_id: new_session_id.clone(),
            profile_id,
            connection_id: connection_id.clone(),
            title,
            rows,
            cols,
            term_type,
        };

        let (cmd_tx, cmd_rx) = mpsc::unbounded_channel::<SshCommand>();
        let (read_half, write_half) = channel.split();

        CONNECTION_STORE
            .lock()
            .unwrap()
            .insert(new_session_id.clone(), SshChannel { cmd_tx });
        SESSION_STORE
            .lock()
            .unwrap()
            .insert(new_session_id.clone(), session.clone());

        {
            let mut store = SSH_CLIENT_STORE.lock().unwrap();
            if let Some(conn_info) = store.get_mut(&connection_id) {
                conn_info.session_ids.push(new_session_id.clone());
            }
        }

        TOKIO_RUNTIME.spawn(run_session_loop(
            new_session_id.clone(),
            read_half,
            write_half,
            cmd_rx,
        ));

        Ok(session)
    });
    if let Err(error) = &result {
        crate::app_log::log_error("ssh.duplicate", error);
    }
    result
}

pub fn write_to_session(session_id: String, data: Vec<u8>) -> Result<()> {
    let result = (|| {
        let channels = CONNECTION_STORE.lock().unwrap();
        let channel = channels
            .get(&session_id)
            .ok_or_else(|| anyhow!("Session not found"))?;
        channel
            .cmd_tx
            .send(SshCommand::Write(data))
            .map_err(|_| anyhow!("Session closed"))?;
        Ok(())
    })();
    if let Err(error) = &result {
        crate::app_log::log_error("ssh.write", error);
    }
    result
}

pub fn resize_session(session_id: String, rows: u16, cols: u16) -> Result<()> {
    let result = (|| {
        let channels = CONNECTION_STORE.lock().unwrap();
        let channel = channels
            .get(&session_id)
            .ok_or_else(|| anyhow!("Session not found"))?;
        channel
            .cmd_tx
            .send(SshCommand::Resize(rows, cols))
            .map_err(|_| anyhow!("Session closed"))?;

        if let Ok(mut sessions) = SESSION_STORE.lock() {
            if let Some(session) = sessions.get_mut(&session_id) {
                session.rows = rows;
                session.cols = cols;
            }
        }

        Ok(())
    })();
    if let Err(error) = &result {
        crate::app_log::log_error("ssh.resize", error);
    }
    result
}

pub fn close_session(session_id: String) -> Result<bool> {
    let connection_id = SESSION_STORE
        .lock()
        .unwrap()
        .get(&session_id)
        .map(|s| s.connection_id.clone());

    let removed_channel = CONNECTION_STORE.lock().unwrap().remove(&session_id);
    if let Some(channel) = removed_channel.as_ref() {
        let _ = channel.cmd_tx.send(SshCommand::Close);
    }

    let removed_session = SESSION_STORE.lock().unwrap().remove(&session_id);
    OUTPUT_SINK_STORE.lock().unwrap().remove(&session_id);

    if let Some(conn_id) = connection_id {
        let should_remove = {
            let mut client_store = SSH_CLIENT_STORE.lock().unwrap();
            if let Some(conn_info) = client_store.get_mut(&conn_id) {
                conn_info.session_ids.retain(|id| id != &session_id);
                conn_info.session_ids.is_empty()
            } else {
                false
            }
        };
        if should_remove {
            SSH_CLIENT_STORE.lock().unwrap().remove(&conn_id);
        }
    }

    Ok(removed_session.is_some() || removed_channel.is_some())
}

async fn run_session_loop(
    session_id: String,
    mut read_half: russh::ChannelReadHalf,
    write_half: russh::ChannelWriteHalf<russh::client::Msg>,
    mut cmd_rx: mpsc::UnboundedReceiver<SshCommand>,
) {
    loop {
        tokio::select! {
            command = cmd_rx.recv() => {
                match command {
                    Some(SshCommand::Write(data)) => {
                        let mut writer = write_half.make_writer();
                        if let Err(error) = writer.write_all(&data).await {
                            crate::app_log::log_error_message(
                                "ssh.channel.write",
                                &format!("Failed to write to SSH channel: {error:?}"),
                                None,
                            );
                        }
                        if let Err(error) = writer.flush().await {
                            crate::app_log::log_error_message(
                                "ssh.channel.flush",
                                &format!("Failed to flush SSH channel: {error:?}"),
                                None,
                            );
                        }
                    }
                    Some(SshCommand::Resize(rows, cols)) => {
                        if let Err(error) = write_half.window_change(cols as u32, rows as u32, 0, 0).await {
                            crate::app_log::log_error_message(
                                "ssh.channel.resize",
                                &format!("Failed to resize SSH channel: {error:?}"),
                                None,
                            );
                        }
                    }
                    Some(SshCommand::Close) | None => {
                        let _ = write_half.close().await;
                        break;
                    }
                }
            }
            message = read_half.wait() => {
                match message {
                    Some(ChannelMsg::Data { data }) => push_output(&session_id, data.to_vec()),
                    Some(ChannelMsg::ExtendedData { data, .. }) => push_output(&session_id, data.to_vec()),
                    Some(ChannelMsg::Close) | None => break,
                    _ => {}
                }
            }
        }
    }

    cleanup_session_after_loop(&session_id);
}

fn cleanup_session_after_loop(session_id: &str) {
    let connection_id = SESSION_STORE
        .lock()
        .unwrap()
        .get(session_id)
        .map(|s| s.connection_id.clone());
    CONNECTION_STORE.lock().unwrap().remove(session_id);
    SESSION_STORE.lock().unwrap().remove(session_id);
    OUTPUT_SINK_STORE.lock().unwrap().remove(session_id);

    if let Some(conn_id) = connection_id {
        let should_remove = {
            let mut client_store = SSH_CLIENT_STORE.lock().unwrap();
            if let Some(conn_info) = client_store.get_mut(&conn_id) {
                conn_info.session_ids.retain(|id| id != session_id);
                conn_info.session_ids.is_empty()
            } else {
                false
            }
        };
        if should_remove {
            SSH_CLIENT_STORE.lock().unwrap().remove(&conn_id);
        }
    }
}

fn push_output(session_id: &str, data: Vec<u8>) {
    let sink = OUTPUT_SINK_STORE.lock().unwrap().get(session_id).cloned();
    if let Some(sink) = sink {
        let _ = sink.add(data);
    }
}

#[cfg(test)]
fn register_session_for_test(profile_id: String, title: String, term_type: String) -> SshSession {
    let session_id = Uuid::new_v4().to_string();
    let connection_id = Uuid::new_v4().to_string();
    let (cmd_tx, mut cmd_rx) = mpsc::unbounded_channel::<SshCommand>();
    let session = SshSession {
        session_id: session_id.clone(),
        profile_id,
        connection_id: connection_id.clone(),
        title,
        rows: 24,
        cols: 80,
        term_type,
    };
    CONNECTION_STORE
        .lock()
        .unwrap()
        .insert(session_id.clone(), SshChannel { cmd_tx });
    SESSION_STORE
        .lock()
        .unwrap()
        .insert(session_id.clone(), session.clone());
    TOKIO_RUNTIME.spawn(async move {
        while let Some(command) = cmd_rx.recv().await {
            if matches!(command, SshCommand::Close) {
                break;
            }
        }
    });
    session
}

#[cfg(test)]
fn clear_sessions_for_test() -> std::sync::MutexGuard<'static, ()> {
    let guard = crate::test_support::WORKSPACE_LOCK.lock().unwrap();
    SESSION_STORE.lock().unwrap().clear();
    CONNECTION_STORE.lock().unwrap().clear();
    OUTPUT_SINK_STORE.lock().unwrap().clear();
    SSH_CLIENT_STORE.lock().unwrap().clear();
    guard
}

#[cfg(test)]
mod tests {
    use std::{env, fs, path::Path};

    use super::*;

    struct TestWorkspace {
        original_dir: std::path::PathBuf,
        temp_dir: tempfile::TempDir,
    }

    impl TestWorkspace {
        fn new() -> Self {
            let temp_dir = tempfile::tempdir().unwrap();
            let original_dir = env::current_dir().unwrap();
            env::set_current_dir(temp_dir.path()).unwrap();
            Self {
                original_dir,
                temp_dir,
            }
        }

        fn path(&self) -> &Path {
            self.temp_dir.path()
        }

        fn log_dir(&self) -> std::path::PathBuf {
            self.path().join("config").join("log")
        }
    }

    impl Drop for TestWorkspace {
        fn drop(&mut self) {
            env::set_current_dir(&self.original_dir).unwrap();
        }
    }

    fn read_single_log(workspace: &TestWorkspace) -> String {
        let log_file = fs::read_dir(workspace.log_dir())
            .unwrap()
            .next()
            .unwrap()
            .unwrap()
            .path();
        fs::read_to_string(log_file).unwrap()
    }

    #[test]
    fn fails_to_connect_to_invalid_host() {
        let _guard = clear_sessions_for_test();
        let _workspace = TestWorkspace::new();

        let result = connect_profile(
            "profile-1".to_string(),
            "Prod".to_string(),
            "127.0.0.1".to_string(),
            1,
            "user".to_string(),
            "pass".to_string(),
            "xterm-truecolor".to_string(),
            24,
            80,
        );

        assert!(result.is_err());
    }

    #[test]
    fn closes_session_that_does_not_exist() {
        let _guard = clear_sessions_for_test();

        let closed = close_session("nonexistent".to_string()).unwrap();
        assert!(!closed);
    }

    #[test]
    fn write_to_missing_session_fails() {
        let _guard = clear_sessions_for_test();
        let _workspace = TestWorkspace::new();

        let result = write_to_session("missing".to_string(), b"ls\n".to_vec());
        assert!(result.is_err());
    }

    #[test]
    fn resize_missing_session_fails() {
        let _guard = clear_sessions_for_test();
        let _workspace = TestWorkspace::new();

        let result = resize_session("missing".to_string(), 40, 120);
        assert!(result.is_err());
    }

    #[test]
    fn uses_selected_term_type_as_pty_term_type() {
        assert_eq!(pty_term_type("xterm-truecolor"), "xterm-truecolor");
        assert_eq!(pty_term_type("xterm-256color"), "xterm-256color");
        assert_eq!(pty_term_type("xterm-color"), "xterm-color");
    }

    #[test]
    fn registers_test_session_and_sends_commands() {
        let _guard = clear_sessions_for_test();
        let session = register_session_for_test(
            "profile-1".to_string(),
            "Prod".to_string(),
            "xterm-truecolor".to_string(),
        );

        assert_eq!(session.term_type, "xterm-truecolor");

        write_to_session(session.session_id.clone(), b"pwd\n".to_vec()).unwrap();
        resize_session(session.session_id.clone(), 30, 100).unwrap();
        assert!(close_session(session.session_id).unwrap());
    }

    #[test]
    fn logs_write_to_missing_session_errors_without_terminal_data() {
        let _guard = clear_sessions_for_test();
        let workspace = TestWorkspace::new();

        let result = write_to_session("missing".to_string(), b"password=secret\n".to_vec());

        assert!(result.is_err());
        let log = read_single_log(&workspace);
        assert!(log.contains("ERROR backend ssh.write"));
        assert!(log.contains("Session not found"));
        assert!(!log.contains("password=secret"));
    }

    #[test]
    fn logs_duplicate_missing_session_errors() {
        let _guard = clear_sessions_for_test();
        let workspace = TestWorkspace::new();

        let result = duplicate_session("nonexistent".to_string());

        assert!(result.is_err());
        let log = read_single_log(&workspace);
        assert!(log.contains("ERROR backend ssh.duplicate"));
        assert!(log.contains("Session not found"));
    }

    #[test]
    fn duplicate_missing_session_fails() {
        let _guard = clear_sessions_for_test();
        let _workspace = TestWorkspace::new();

        let result = duplicate_session("nonexistent".to_string());
        assert!(result.is_err());
    }
}
