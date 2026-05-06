use std::collections::HashMap;
use std::env;
use std::ffi::OsString;
use std::io::{Read, Write};
use std::path::PathBuf;
use std::sync::{mpsc, Mutex};
use std::thread;

use anyhow::{anyhow, Result};
use once_cell::sync::Lazy;
use portable_pty::{native_pty_system, CommandBuilder, MasterPty, PtySize};
use uuid::Uuid;

use crate::frb_generated::StreamSink;

static SESSION_STORE: Lazy<Mutex<HashMap<String, LocalTerminalHandle>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static OUTPUT_SINK_STORE: Lazy<Mutex<HashMap<String, StreamSink<Vec<u8>>>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct LocalTerminalSession {
    pub session_id: String,
    pub title: String,
}

enum LocalTerminalCommand {
    Write(Vec<u8>),
    Resize(u16, u16),
    Close,
}

struct LocalTerminalHandle {
    cmd_tx: mpsc::Sender<LocalTerminalCommand>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ShellPlatform {
    Windows,
    #[cfg_attr(windows, allow(dead_code))]
    Unix,
}

fn default_shell_for_platform<F>(
    platform: ShellPlatform,
    env_shell: Option<OsString>,
    command_exists: F,
) -> PathBuf
where
    F: Fn(&str) -> bool,
{
    match platform {
        ShellPlatform::Windows => {
            if command_exists("pwsh") {
                PathBuf::from("pwsh")
            } else {
                PathBuf::from("powershell.exe")
            }
        }
        ShellPlatform::Unix => env_shell
            .filter(|value| !value.is_empty())
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("/bin/sh")),
    }
}

fn command_exists(command: &str) -> bool {
    let Some(path_var) = env::var_os("PATH") else {
        return false;
    };

    for dir in env::split_paths(&path_var) {
        let candidate = dir.join(command);
        if candidate.is_file() {
            return true;
        }
        #[cfg(windows)]
        {
            for ext in [".exe", ".cmd", ".bat"] {
                if dir.join(format!("{command}{ext}")).is_file() {
                    return true;
                }
            }
        }
    }
    false
}

fn default_shell() -> PathBuf {
    #[cfg(windows)]
    {
        default_shell_for_platform(ShellPlatform::Windows, None, command_exists)
    }
    #[cfg(not(windows))]
    {
        default_shell_for_platform(ShellPlatform::Unix, env::var_os("SHELL"), command_exists)
    }
}

fn home_dir() -> Result<PathBuf> {
    #[cfg(windows)]
    let value = env::var_os("USERPROFILE");
    #[cfg(not(windows))]
    let value = env::var_os("HOME");

    value
        .map(PathBuf::from)
        .filter(|path| !path.as_os_str().is_empty())
        .ok_or_else(|| anyhow!("Home directory not found"))
}

fn pty_size_from(rows: Option<u16>, cols: Option<u16>) -> PtySize {
    PtySize {
        rows: rows.unwrap_or(24).max(1),
        cols: cols.unwrap_or(80).max(1),
        pixel_width: 0,
        pixel_height: 0,
    }
}

pub fn spawn_local_terminal(rows: Option<u16>, cols: Option<u16>) -> Result<LocalTerminalSession> {
    let shell = default_shell();
    let cwd = home_dir()?;
    let pty_system = native_pty_system();
    let pair = pty_system.openpty(pty_size_from(rows, cols))?;

    let mut command = CommandBuilder::new(shell);
    command.cwd(cwd);
    command.env("TERM", "xterm-256color");

    let child = pair.slave.spawn_command(command)?;
    drop(pair.slave);

    let reader = pair.master.try_clone_reader()?;
    let writer = pair.master.take_writer()?;
    let master = pair.master;
    let session_id = Uuid::new_v4().to_string();
    let (cmd_tx, cmd_rx) = mpsc::channel::<LocalTerminalCommand>();

    SESSION_STORE
        .lock()
        .unwrap()
        .insert(session_id.clone(), LocalTerminalHandle { cmd_tx });

    let output_session_id = session_id.clone();
    thread::spawn(move || run_output_loop(output_session_id, reader));

    let command_session_id = session_id.clone();
    thread::spawn(move || run_command_loop(command_session_id, master, writer, child, cmd_rx));

    Ok(LocalTerminalSession {
        session_id,
        title: "terminal".to_string(),
    })
}

pub fn create_local_terminal_output_stream(session_id: String, sink: StreamSink<Vec<u8>>) {
    OUTPUT_SINK_STORE.lock().unwrap().insert(session_id, sink);
}

pub fn write_to_local_terminal(session_id: String, data: Vec<u8>) -> Result<()> {
    let sessions = SESSION_STORE.lock().unwrap();
    let session = sessions
        .get(&session_id)
        .ok_or_else(|| anyhow!("Local terminal session not found"))?;
    session
        .cmd_tx
        .send(LocalTerminalCommand::Write(data))
        .map_err(|_| anyhow!("Local terminal session closed"))
}

pub fn resize_local_terminal(session_id: String, rows: u16, cols: u16) -> Result<()> {
    let sessions = SESSION_STORE.lock().unwrap();
    let session = sessions
        .get(&session_id)
        .ok_or_else(|| anyhow!("Local terminal session not found"))?;
    session
        .cmd_tx
        .send(LocalTerminalCommand::Resize(rows.max(1), cols.max(1)))
        .map_err(|_| anyhow!("Local terminal session closed"))
}

pub fn close_local_terminal(session_id: String) -> Result<()> {
    let session = SESSION_STORE
        .lock()
        .unwrap()
        .remove(&session_id)
        .ok_or_else(|| anyhow!("Local terminal session not found"))?;
    OUTPUT_SINK_STORE.lock().unwrap().remove(&session_id);
    session
        .cmd_tx
        .send(LocalTerminalCommand::Close)
        .map_err(|_| anyhow!("Local terminal session closed"))
}

fn run_output_loop(session_id: String, mut reader: Box<dyn Read + Send>) {
    let mut buffer = [0_u8; 8192];
    loop {
        match reader.read(&mut buffer) {
            Ok(0) => break,
            Ok(size) => push_output(&session_id, buffer[..size].to_vec()),
            Err(error) => {
                crate::app_log::log_error_message(
                    "local_terminal.read",
                    &format!("Failed to read local terminal output: {error:?}"),
                    None,
                );
                break;
            }
        }
    }
    cleanup_session_after_loop(&session_id);
}

fn run_command_loop(
    session_id: String,
    master: Box<dyn MasterPty + Send>,
    mut writer: Box<dyn Write + Send>,
    mut child: Box<dyn portable_pty::Child + Send + Sync>,
    cmd_rx: mpsc::Receiver<LocalTerminalCommand>,
) {
    while let Ok(command) = cmd_rx.recv() {
        match command {
            LocalTerminalCommand::Write(data) => {
                if let Err(error) = writer.write_all(&data) {
                    crate::app_log::log_error_message(
                        "local_terminal.write",
                        &format!("Failed to write local terminal input: {error:?}"),
                        None,
                    );
                    break;
                }
                if let Err(error) = writer.flush() {
                    crate::app_log::log_error_message(
                        "local_terminal.flush",
                        &format!("Failed to flush local terminal input: {error:?}"),
                        None,
                    );
                    break;
                }
            }
            LocalTerminalCommand::Resize(rows, cols) => {
                if let Err(error) = master.resize(pty_size_from(Some(rows), Some(cols))) {
                    crate::app_log::log_error_message(
                        "local_terminal.resize",
                        &format!("Failed to resize local terminal: {error:?}"),
                        None,
                    );
                }
            }
            LocalTerminalCommand::Close => {
                let _ = child.kill();
                break;
            }
        }
    }
    cleanup_session_after_loop(&session_id);
}

fn cleanup_session_after_loop(session_id: &str) {
    SESSION_STORE.lock().unwrap().remove(session_id);
    OUTPUT_SINK_STORE.lock().unwrap().remove(session_id);
}

fn push_output(session_id: &str, data: Vec<u8>) {
    let sink = OUTPUT_SINK_STORE.lock().unwrap().get(session_id).cloned();
    if let Some(sink) = sink {
        let _ = sink.add(data);
    }
}

#[cfg(test)]
fn clear_sessions_for_test() -> std::sync::MutexGuard<'static, ()> {
    let guard = crate::test_support::WORKSPACE_LOCK.lock().unwrap();
    SESSION_STORE.lock().unwrap().clear();
    OUTPUT_SINK_STORE.lock().unwrap().clear();
    guard
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pty_size_clamps_zero_dimensions() {
        let size = pty_size_from(Some(0), Some(0));

        assert_eq!(size.rows, 1);
        assert_eq!(size.cols, 1);
        assert_eq!(size.pixel_width, 0);
        assert_eq!(size.pixel_height, 0);
    }

    #[test]
    fn pty_size_uses_default_dimensions() {
        let size = pty_size_from(None, None);

        assert_eq!(size.rows, 24);
        assert_eq!(size.cols, 80);
    }

    #[test]
    fn windows_shell_selection_prefers_pwsh_when_available() {
        let shell =
            default_shell_for_platform(ShellPlatform::Windows, None, |command| command == "pwsh");

        assert_eq!(shell, PathBuf::from("pwsh"));
    }

    #[test]
    fn windows_shell_selection_falls_back_to_powershell() {
        let shell = default_shell_for_platform(ShellPlatform::Windows, None, |_| false);

        assert_eq!(shell, PathBuf::from("powershell.exe"));
    }

    #[test]
    fn unix_shell_selection_uses_shell_env() {
        let shell = default_shell_for_platform(
            ShellPlatform::Unix,
            Some(OsString::from("/usr/bin/fish")),
            |_| false,
        );

        assert_eq!(shell, PathBuf::from("/usr/bin/fish"));
    }

    #[test]
    fn unix_shell_selection_falls_back_to_bin_sh() {
        let shell = default_shell_for_platform(ShellPlatform::Unix, None, |_| false);

        assert_eq!(shell, PathBuf::from("/bin/sh"));
    }

    #[test]
    fn missing_session_write_fails() {
        let _guard = clear_sessions_for_test();

        let result = write_to_local_terminal("missing".to_string(), b"echo hi\n".to_vec());

        assert!(result.is_err());
    }

    #[test]
    fn missing_session_resize_fails() {
        let _guard = clear_sessions_for_test();

        let result = resize_local_terminal("missing".to_string(), 30, 100);

        assert!(result.is_err());
    }

    #[test]
    fn missing_session_close_fails() {
        let _guard = clear_sessions_for_test();

        let result = close_local_terminal("missing".to_string());

        assert!(result.is_err());
    }

    #[test]
    fn close_removes_spawned_session_from_store() {
        let _guard = clear_sessions_for_test();

        let session = spawn_local_terminal(Some(24), Some(80)).unwrap();
        assert!(SESSION_STORE
            .lock()
            .unwrap()
            .contains_key(&session.session_id));

        close_local_terminal(session.session_id.clone()).unwrap();

        assert!(!SESSION_STORE
            .lock()
            .unwrap()
            .contains_key(&session.session_id));
    }
}
