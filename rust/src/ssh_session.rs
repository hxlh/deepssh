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
static TOKIO_RUNTIME: Lazy<Runtime> = Lazy::new(|| {
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
) -> Result<SshSession> {
    TOKIO_RUNTIME.block_on(async move {
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
        let rows = 24;
        let cols = 80;
        channel
            .request_pty(true, "xterm", cols as u32, rows as u32, 0, 0, &[])
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
    })
}

pub fn duplicate_session(session_id: String) -> Result<SshSession> {
    TOKIO_RUNTIME.block_on(async move {
        let (connection_id, profile_id, title, rows, cols) = {
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
        channel
            .request_pty(true, "xterm", cols as u32, rows as u32, 0, 0, &[])
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
    })
}

pub fn write_to_session(session_id: String, data: Vec<u8>) -> Result<()> {
    let channels = CONNECTION_STORE.lock().unwrap();
    let channel = channels
        .get(&session_id)
        .ok_or_else(|| anyhow!("Session not found"))?;
    channel
        .cmd_tx
        .send(SshCommand::Write(data))
        .map_err(|_| anyhow!("Session closed"))?;
    Ok(())
}

pub fn resize_session(session_id: String, rows: u16, cols: u16) -> Result<()> {
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
                        let _ = writer.write_all(&data).await;
                        let _ = writer.flush().await;
                    }
                    Some(SshCommand::Resize(rows, cols)) => {
                        let _ = write_half.window_change(cols as u32, rows as u32, 0, 0).await;
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
fn register_session_for_test(profile_id: String, title: String) -> SshSession {
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
    let guard = TEST_LOCK.lock().unwrap();
    SESSION_STORE.lock().unwrap().clear();
    CONNECTION_STORE.lock().unwrap().clear();
    OUTPUT_SINK_STORE.lock().unwrap().clear();
    SSH_CLIENT_STORE.lock().unwrap().clear();
    guard
}

#[cfg(test)]
static TEST_LOCK: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fails_to_connect_to_invalid_host() {
        let _guard = clear_sessions_for_test();

        let result = connect_profile(
            "profile-1".to_string(),
            "Prod".to_string(),
            "127.0.0.1".to_string(),
            1,
            "user".to_string(),
            "pass".to_string(),
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

        let result = write_to_session("missing".to_string(), b"ls\n".to_vec());
        assert!(result.is_err());
    }

    #[test]
    fn resize_missing_session_fails() {
        let _guard = clear_sessions_for_test();

        let result = resize_session("missing".to_string(), 40, 120);
        assert!(result.is_err());
    }

    #[test]
    fn registers_test_session_and_sends_commands() {
        let _guard = clear_sessions_for_test();
        let session = register_session_for_test("profile-1".to_string(), "Prod".to_string());

        write_to_session(session.session_id.clone(), b"pwd\n".to_vec()).unwrap();
        resize_session(session.session_id.clone(), 30, 100).unwrap();
        assert!(close_session(session.session_id).unwrap());
    }

    #[test]
    fn duplicate_missing_session_fails() {
        let _guard = clear_sessions_for_test();

        let result = duplicate_session("nonexistent".to_string());
        assert!(result.is_err());
    }
}
