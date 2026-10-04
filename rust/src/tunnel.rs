use std::{
    collections::HashMap,
    fs,
    net::SocketAddr,
    sync::{
        atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering},
        mpsc as std_mpsc, Arc, Mutex,
    },
    time::Duration,
};

use anyhow::{anyhow, Context, Result};
use once_cell::sync::Lazy;
use russh::client;
use russh::keys::ssh_key;
use russh::{ChannelMsg, Disconnect};
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::oneshot;
use uuid::Uuid;

use crate::config_path::config_file_path;
use crate::profile;
use crate::ssh_auth::{self, SshAuthCredential, SshConnectError};
use crate::ssh_session::TOKIO_RUNTIME;

const CONFIG_FILE_NAME: &str = "tunnels.yaml";

static TUNNEL_STORE: Lazy<Mutex<TunnelStore>> = Lazy::new(|| Mutex::new(TunnelStore::default()));
static RUNTIME_STORE: Lazy<Mutex<HashMap<String, TunnelRuntime>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

#[flutter_rust_bridge::frb(ignore)]
#[derive(Default)]
struct TunnelStore {
    configs: Vec<TunnelConfig>,
    initialized: bool,
}

static NEXT_RUNTIME_GENERATION: AtomicU64 = AtomicU64::new(1);

type TunnelReadySender = std_mpsc::Sender<Result<u16, String>>;

#[flutter_rust_bridge::frb(ignore)]
struct TunnelRuntime {
    generation: u64,
    status: TunnelRuntimeStatus,
    // Actual bound port when the configured listen port is 0 (auto-assign).
    active_listen_port: Option<u16>,
    stop_tx: Option<oneshot::Sender<()>>,
    // Signalled when the spawned runtime task has fully finished and dropped
    // its listener, so stop/start cannot race on the same local port.
    done_rx: Option<std_mpsc::Receiver<()>>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum TunnelForwardType {
    Local,
    Remote,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum TunnelRuntimeStatus {
    Stopped,
    Waiting,
    Forwarding,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TunnelConfig {
    pub id: String,
    pub name: String,
    pub forward_type: TunnelForwardType,
    pub ssh_profile_id: String,
    pub listen_host: String,
    pub listen_port: u16,
    pub target_host: String,
    pub target_port: u16,
    pub status: TunnelRuntimeStatus,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TunnelStartResult {
    pub tunnel: Option<TunnelConfig>,
    pub error: Option<SshConnectError>,
}

fn tunnel_start_success(tunnel: TunnelConfig) -> TunnelStartResult {
    TunnelStartResult {
        tunnel: Some(tunnel),
        error: None,
    }
}

fn tunnel_start_failure(error: SshConnectError) -> TunnelStartResult {
    TunnelStartResult {
        tunnel: None,
        error: Some(error),
    }
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Default, Deserialize, Serialize)]
struct TunnelsFile {
    #[serde(default)]
    tunnels: Vec<TunnelConfigFile>,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
struct TunnelConfigFile {
    #[serde(default)]
    id: String,
    name: String,
    forward_type: TunnelForwardTypeFile,
    ssh_profile_id: String,
    listen_host: String,
    listen_port: u16,
    target_host: String,
    target_port: u16,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
enum TunnelForwardTypeFile {
    Local,
    Remote,
}

#[derive(Clone)]
#[flutter_rust_bridge::frb(ignore)]
struct RemoteRoute {
    target_host: String,
    target_port: u16,
}

#[derive(Clone)]
#[flutter_rust_bridge::frb(ignore)]
struct TunnelClientHandler {
    remote_routes: Arc<Mutex<HashMap<String, RemoteRoute>>>,
}

impl client::Handler for TunnelClientHandler {
    type Error = anyhow::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &ssh_key::PublicKey,
    ) -> Result<bool, Self::Error> {
        Ok(true)
    }

    async fn server_channel_open_forwarded_tcpip(
        &mut self,
        channel: russh::Channel<client::Msg>,
        connected_address: &str,
        connected_port: u32,
        _originator_address: &str,
        _originator_port: u32,
        _session: &mut client::Session,
    ) -> Result<(), Self::Error> {
        let key = remote_route_key(connected_address, connected_port as u16);
        let route = self.remote_routes.lock().unwrap().get(&key).cloned();
        match route {
            Some(route) => {
                TOKIO_RUNTIME.spawn(async move {
                    match TcpStream::connect(format!("{}:{}", route.target_host, route.target_port))
                        .await
                    {
                        Ok(stream) => {
                            if let Err(error) = relay_tcp_stream_and_channel(stream, channel).await
                            {
                                log_tunnel_connection_error("tunnel.remote.connection", &error);
                            }
                        }
                        Err(error) => {
                            crate::app_log::log_error_message(
                                "tunnel.remote.target",
                                &format!("Failed to connect remote tunnel target: {error:?}"),
                                None,
                            );
                        }
                    }
                });
            }
            None => {
                // A forwarded connection arrived for a port we no longer have
                // a route for (for example a stale forward on the server).
                // Complete the close handshake instead of leaking the channel.
                TOKIO_RUNTIME.spawn(async move {
                    let _ = channel.eof().await;
                    let _ = channel.close().await;
                });
            }
        }
        Ok(())
    }
}
impl From<TunnelForwardTypeFile> for TunnelForwardType {
    fn from(value: TunnelForwardTypeFile) -> Self {
        match value {
            TunnelForwardTypeFile::Local => TunnelForwardType::Local,
            TunnelForwardTypeFile::Remote => TunnelForwardType::Remote,
        }
    }
}

impl From<&TunnelForwardType> for TunnelForwardTypeFile {
    fn from(value: &TunnelForwardType) -> Self {
        match value {
            TunnelForwardType::Local => TunnelForwardTypeFile::Local,
            TunnelForwardType::Remote => TunnelForwardTypeFile::Remote,
        }
    }
}

impl TunnelConfigFile {
    fn into_config_with_migration(self) -> (TunnelConfig, bool) {
        let missing_id = self.id.is_empty();
        let id = if missing_id {
            Uuid::new_v4().to_string()
        } else {
            self.id
        };
        (
            TunnelConfig {
                id,
                name: self.name,
                forward_type: self.forward_type.into(),
                ssh_profile_id: self.ssh_profile_id,
                listen_host: self.listen_host,
                listen_port: self.listen_port,
                target_host: self.target_host,
                target_port: self.target_port,
                status: TunnelRuntimeStatus::Stopped,
            },
            missing_id,
        )
    }
}

impl From<&TunnelConfig> for TunnelConfigFile {
    fn from(config: &TunnelConfig) -> Self {
        Self {
            id: config.id.clone(),
            name: config.name.clone(),
            forward_type: (&config.forward_type).into(),
            ssh_profile_id: config.ssh_profile_id.clone(),
            listen_host: config.listen_host.clone(),
            listen_port: config.listen_port,
            target_host: config.target_host.clone(),
            target_port: config.target_port,
        }
    }
}

fn remote_route_key(address: &str, port: u16) -> String {
    format!("{}:{}", address, port)
}

fn next_backoff_delay(current: Duration) -> Duration {
    let doubled = current.as_secs().saturating_mul(2);
    Duration::from_secs(doubled.min(60).max(1))
}

async fn sleep_or_stop(stop_rx: &mut oneshot::Receiver<()>, delay: Duration) -> bool {
    tokio::select! {
        _ = &mut *stop_rx => true,
        _ = tokio::time::sleep(delay) => false,
    }
}

fn is_channel_open_failure(message: &str) -> bool {
    message.contains("Failed to open channel")
}

/// How many consecutive channel-open refusals (relays *and* readiness probes)
/// before the SSH session is thrown away and rebuilt.
///
/// `ConnectFailed` usually means the target is down, and retrying on the same
/// session is right for that. But the server also answers it when the session
/// itself can no longer take channels — OpenSSH's `MaxSessions` is 10 by
/// default, and it also hits this once it runs out of file descriptors. In that
/// case the SSH connection stays perfectly alive, so the `handle.is_closed()`
/// reconnect below never fires: the listener stays bound, nothing accepts, and
/// the tunnel is wedged until it is stopped and started again.
const MAX_CHANNEL_OPEN_FAILURES: u32 = 3;

/// Consecutive channel-open refusals on one tunnel runtime.
///
/// A single run of refusals means the session can no longer take channels and
/// has to be rebuilt; a refusal followed by a successful probe (which itself
/// opens a channel) resets the run.
struct ChannelOpenFailures {
    count: AtomicU32,
}

impl ChannelOpenFailures {
    fn new() -> Self {
        ChannelOpenFailures {
            count: AtomicU32::new(0),
        }
    }

    fn record(&self) {
        self.count.fetch_add(1, Ordering::Relaxed);
    }

    /// A probe opened a channel, so whatever refused earlier is healthy again.
    fn reset(&self) {
        self.count.store(0, Ordering::Relaxed);
    }

    fn should_recycle(&self) -> bool {
        self.count.load(Ordering::Relaxed) >= MAX_CHANNEL_OPEN_FAILURES
    }
}

fn is_expected_connection_close(message: &str) -> bool {
    // Resets and aborted sockets are normal when a browser or client cancels a
    // forwarded request. Logging them as errors produced tens of thousands of
    // noise lines and hid the real reconnect failures.
    const EXPECTED: [&str; 6] = [
        "os error 10053",
        "os error 10054",
        "os error 104",
        "os error 32",
        "Connection reset",
        "Broken pipe",
    ];
    EXPECTED.iter().any(|needle| message.contains(needle))
}

fn log_tunnel_connection_error(scope: &str, error: &anyhow::Error) {
    let message = format!("{error:#}");
    if is_expected_connection_close(&message) {
        return;
    }
    crate::app_log::log_error(scope, error);
}

async fn local_tcp_port_is_open(host: &str, port: u16) -> bool {
    let addr = format!("{}:{}", host, port);
    tokio::time::timeout(Duration::from_millis(800), TcpStream::connect(addr))
        .await
        .map(|result| result.is_ok())
        .unwrap_or(false)
}
fn load_tunnels_from_disk() -> Result<Vec<TunnelConfig>> {
    let path = config_file_path(CONFIG_FILE_NAME)?;
    let content = match fs::read_to_string(&path) {
        Ok(content) => content,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(error) => {
            return Err(error).with_context(|| format!("Failed to read {}", path.display()))
        }
    };
    let file: TunnelsFile = serde_yaml::from_str(&content)
        .with_context(|| format!("Failed to parse {}", path.display()))?;
    let mut migrated = false;
    let configs = file
        .tunnels
        .into_iter()
        .map(|config| {
            let (tunnel, changed) = config.into_config_with_migration();
            migrated |= changed;
            tunnel
        })
        .collect::<Vec<_>>();
    if migrated {
        write_tunnels_to_disk(&configs)?;
    }
    Ok(configs)
}

fn write_tunnels_to_disk(configs: &[TunnelConfig]) -> Result<()> {
    let path = config_file_path(CONFIG_FILE_NAME)?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).with_context(|| format!("Failed to create {parent:?}"))?;
    }
    let file = TunnelsFile {
        tunnels: configs.iter().map(TunnelConfigFile::from).collect(),
    };
    let content = serde_yaml::to_string(&file).context("Failed to serialize tunnels")?;
    fs::write(&path, content).with_context(|| format!("Failed to write {}", path.display()))?;
    Ok(())
}

fn ensure_tunnels_loaded(store: &mut TunnelStore) -> Result<()> {
    if store.initialized {
        return Ok(());
    }
    store.configs = load_tunnels_from_disk()?;
    store.initialized = true;
    Ok(())
}

fn with_runtime_status(mut config: TunnelConfig) -> TunnelConfig {
    let runtimes = RUNTIME_STORE.lock().unwrap();
    match runtimes.get(&config.id) {
        Some(runtime) => {
            config.status = runtime.status.clone();
            if let Some(port) = runtime.active_listen_port {
                config.listen_port = port;
            }
        }
        None => config.status = TunnelRuntimeStatus::Stopped,
    }
    config
}

fn runtime_status(id: &str) -> TunnelRuntimeStatus {
    RUNTIME_STORE
        .lock()
        .unwrap()
        .get(id)
        .map(|runtime| runtime.status.clone())
        .unwrap_or(TunnelRuntimeStatus::Stopped)
}

#[cfg(test)]
fn set_runtime_status(id: &str, status: TunnelRuntimeStatus) {
    let mut runtimes = RUNTIME_STORE.lock().unwrap();
    if matches!(status, TunnelRuntimeStatus::Stopped) {
        runtimes.remove(id);
        return;
    }
    runtimes
        .entry(id.to_string())
        .and_modify(|runtime| runtime.status = status.clone())
        .or_insert(TunnelRuntime {
            generation: 0,
            status,
            active_listen_port: None,
            stop_tx: None,
            done_rx: None,
        });
}

fn update_runtime_status(id: &str, generation: u64, status: TunnelRuntimeStatus) {
    let mut runtimes = RUNTIME_STORE.lock().unwrap();
    if let Some(runtime) = runtimes.get_mut(id) {
        if runtime.generation == generation {
            runtime.status = status;
        }
    }
}

fn update_runtime_listen_port(id: &str, generation: u64, port: u16) {
    let mut runtimes = RUNTIME_STORE.lock().unwrap();
    if let Some(runtime) = runtimes.get_mut(id) {
        if runtime.generation == generation {
            runtime.active_listen_port = Some(port);
        }
    }
}

fn remove_runtime_if_generation(id: &str, generation: u64) {
    let mut runtimes = RUNTIME_STORE.lock().unwrap();
    let matches_generation = runtimes
        .get(id)
        .is_some_and(|runtime| runtime.generation == generation);
    if matches_generation {
        runtimes.remove(id);
    }
}

fn stop_runtime_and_wait(id: &str) {
    let runtime = RUNTIME_STORE.lock().unwrap().remove(id);
    let Some(mut runtime) = runtime else {
        return;
    };
    if let Some(stop_tx) = runtime.stop_tx.take() {
        let _ = stop_tx.send(());
    }
    if let Some(done_rx) = runtime.done_rx.take() {
        // Wait for the task to drop its listener before returning, otherwise a
        // quick stop/start rebinds the same port and fails with EADDRINUSE.
        let _ = done_rx.recv_timeout(Duration::from_secs(5));
    }
}

async fn connect_ssh_profile(
    profile_id: &str,
    credential: SshAuthCredential,
    remote_routes: Arc<Mutex<HashMap<String, RemoteRoute>>>,
) -> Result<client::Handle<TunnelClientHandler>> {
    let ssh_profile = profile::list_profiles()?
        .into_iter()
        .find(|profile| profile.id == profile_id)
        .ok_or_else(|| anyhow!("SSH profile not found"))?;
    let addr = format!("{}:{}", ssh_profile.host, ssh_profile.port);
    let mut config = client::Config::default();
    config.nodelay = true;
    // A silently dropped link (server restart, NAT idle timeout) used to stay
    // undetected for a long time. Keepalives let the session task notice and
    // close, which is what triggers the reconnect loop below.
    config.keepalive_interval = Some(Duration::from_secs(15));
    config.keepalive_max = 3;
    let config = Arc::new(config);
    let mut handle = client::connect(config, addr, TunnelClientHandler { remote_routes })
        .await
        .map_err(|error| anyhow!("SSH connect failed: {:?}", error))?;
    ssh_auth::authenticate(&mut handle, ssh_profile.username, credential)
        .await
        .map_err(|error| anyhow!(error.message))?;
    Ok(handle)
}

async fn relay_tcp_stream_and_channel(
    mut stream: TcpStream,
    mut channel: russh::Channel<client::Msg>,
) -> Result<()> {
    let (mut reader, mut writer) = stream.split();
    let mut stream_closed = false;
    let mut buf = vec![0; 65536];

    // Drive the relay until either half closes. Every exit path `break`s out
    // instead of returning early, so control always reaches `channel.close()`
    // below. russh's plain `Channel` does NOT send `SSH_MSG_CHANNEL_CLOSE` on
    // drop (only the opt-in `ChannelCloseOnDrop` / `into_stream` path does),
    // and the server keeps the channel — and the target socket behind it —
    // alive until it sees CLOSE. Skipping it leaks one CLOSE_WAIT channel per
    // forwarded connection, which accumulates to hundreds of sockets and
    // hundreds of MB on a long-lived tunnel.
    let outcome: Result<()> = loop {
        tokio::select! {
            read = reader.read(&mut buf), if !stream_closed => {
                match read {
                    Ok(0) => {
                        stream_closed = true;
                        if let Err(error) = channel.eof().await {
                            break Err(error.into());
                        }
                    }
                    Ok(n) => {
                        if let Err(error) = channel.data(&buf[..n]).await {
                            break Err(error.into());
                        }
                    }
                    Err(error) => break Err(error.into()),
                }
            }
            message = channel.wait() => {
                match message {
                    Some(ChannelMsg::Data { data }) => {
                        if let Err(error) = writer.write_all(&data).await {
                            break Err(error.into());
                        }
                    }
                    Some(ChannelMsg::ExtendedData { data, .. }) => {
                        if let Err(error) = writer.write_all(&data).await {
                            break Err(error.into());
                        }
                    }
                    Some(ChannelMsg::Eof) | Some(ChannelMsg::Close) | None => {
                        if !stream_closed {
                            let _ = channel.eof().await;
                        }
                        break Ok(());
                    }
                    _ => {}
                }
            }
        }
    };

    // Always complete the close handshake so the server frees the channel and
    // the target socket. Best-effort: a failure here is still reported via
    // `outcome` so callers see the original relay error.
    let _ = channel.close().await;
    outcome
}

async fn remote_target_is_open_via_ssh(
    handle: &client::Handle<TunnelClientHandler>,
    target_host: &str,
    target_port: u16,
) -> bool {
    match handle
        .channel_open_direct_tcpip(target_host.to_string(), target_port.into(), "127.0.0.1", 0)
        .await
    {
        Ok(channel) => {
            // This probe channel must be closed explicitly too; otherwise each
            // readiness check leaks a channel on the server (same root cause as
            // the relay). `close()` completes the handshake on its own.
            let _ = channel.eof().await;
            let _ = channel.close().await;
            true
        }
        Err(_) => false,
    }
}
pub fn list_tunnels() -> Result<Vec<TunnelConfig>> {
    let result = (|| {
        let mut store = TUNNEL_STORE.lock().unwrap();
        ensure_tunnels_loaded(&mut store)?;
        Ok(store
            .configs
            .iter()
            .cloned()
            .map(with_runtime_status)
            .collect())
    })();
    if let Err(error) = &result {
        crate::app_log::log_error("tunnel.list", error);
    }
    result
}

pub fn create_tunnel(
    name: String,
    forward_type: TunnelForwardType,
    ssh_profile_id: String,
    listen_host: String,
    listen_port: u16,
    target_host: String,
    target_port: u16,
) -> Result<TunnelConfig> {
    let result = (|| {
        let mut store = TUNNEL_STORE.lock().unwrap();
        ensure_tunnels_loaded(&mut store)?;
        let tunnel = TunnelConfig {
            id: Uuid::new_v4().to_string(),
            name,
            forward_type,
            ssh_profile_id,
            listen_host,
            listen_port,
            target_host,
            target_port,
            status: TunnelRuntimeStatus::Stopped,
        };
        store.configs.push(tunnel.clone());
        write_tunnels_to_disk(&store.configs)?;
        Ok(tunnel)
    })();
    if let Err(error) = &result {
        crate::app_log::log_error("tunnel.create", error);
    }
    result
}

pub fn update_tunnel(
    id: String,
    name: String,
    forward_type: TunnelForwardType,
    ssh_profile_id: String,
    listen_host: String,
    listen_port: u16,
    target_host: String,
    target_port: u16,
) -> Result<TunnelConfig> {
    let result = (|| {
        let mut store = TUNNEL_STORE.lock().unwrap();
        ensure_tunnels_loaded(&mut store)?;
        let index = store
            .configs
            .iter()
            .position(|config| config.id == id)
            .ok_or_else(|| anyhow!("Tunnel not found"))?;
        let status = runtime_status(&id);
        let tunnel = TunnelConfig {
            id,
            name,
            forward_type,
            ssh_profile_id,
            listen_host,
            listen_port,
            target_host,
            target_port,
            status,
        };
        store.configs[index] = tunnel.clone();
        write_tunnels_to_disk(&store.configs)?;
        Ok(tunnel)
    })();
    if let Err(error) = &result {
        crate::app_log::log_error("tunnel.update", error);
    }
    result
}

pub fn delete_tunnel(id: String) -> Result<()> {
    let result = (|| {
        let mut store = TUNNEL_STORE.lock().unwrap();
        ensure_tunnels_loaded(&mut store)?;
        let index = store
            .configs
            .iter()
            .position(|config| config.id == id)
            .ok_or_else(|| anyhow!("Tunnel not found"))?;
        store.configs.remove(index);
        write_tunnels_to_disk(&store.configs)?;
        stop_runtime_and_wait(&id);
        Ok(())
    })();
    if let Err(error) = &result {
        crate::app_log::log_error("tunnel.delete", error);
    }
    result
}

pub fn start_tunnel(id: String, credential: SshAuthCredential) -> Result<TunnelStartResult> {
    let result = (|| {
        let tunnel = {
            let mut store = TUNNEL_STORE.lock().unwrap();
            ensure_tunnels_loaded(&mut store)?;
            store
                .configs
                .iter()
                .find(|config| config.id == id)
                .cloned()
                .ok_or_else(|| anyhow!("Tunnel not found"))?
        };

        if RUNTIME_STORE.lock().unwrap().contains_key(&id) {
            return Ok(tunnel_start_success(with_runtime_status(tunnel)));
        }

        if let Some(private_key_path) = &credential.private_key_path {
            if let Err(error) = ssh_auth::load_private_key(
                std::path::Path::new(private_key_path),
                credential.passphrase.as_deref(),
            ) {
                return Ok(tunnel_start_failure(error));
            }
        }

        let generation = NEXT_RUNTIME_GENERATION.fetch_add(1, Ordering::Relaxed);
        let (stop_tx, stop_rx) = oneshot::channel::<()>();
        let (done_tx, done_rx) = std_mpsc::channel::<()>();
        let (ready_tx, ready_rx) = std_mpsc::channel::<Result<u16, String>>();
        let wait_for_bind = tunnel.forward_type == TunnelForwardType::Local;

        RUNTIME_STORE.lock().unwrap().insert(
            id.clone(),
            TunnelRuntime {
                generation,
                status: TunnelRuntimeStatus::Waiting,
                active_listen_port: None,
                stop_tx: Some(stop_tx),
                done_rx: Some(done_rx),
            },
        );

        TOKIO_RUNTIME.spawn(run_tunnel(
            tunnel.clone(),
            credential,
            stop_rx,
            ready_tx,
            done_tx,
            generation,
        ));

        if wait_for_bind {
            // The local listener is bound before the SSH handshake, so this
            // returns almost immediately. Surfacing a bind failure here is what
            // turns a silent "started then stopped" into a visible error.
            match ready_rx.recv_timeout(Duration::from_secs(5)) {
                Ok(Ok(_)) => {}
                Ok(Err(message)) => {
                    remove_runtime_if_generation(&id, generation);
                    return Err(anyhow!(message));
                }
                Err(_) => {
                    // Still starting; status polling will pick up the result.
                }
            }
        }

        Ok(tunnel_start_success(with_runtime_status(tunnel)))
    })();
    if let Err(error) = &result {
        crate::app_log::log_error("tunnel.start", error);
    }
    result
}

pub fn stop_tunnel(id: String) -> Result<TunnelConfig> {
    let result = (|| {
        let tunnel = {
            let mut store = TUNNEL_STORE.lock().unwrap();
            ensure_tunnels_loaded(&mut store)?;
            store
                .configs
                .iter()
                .find(|config| config.id == id)
                .cloned()
                .ok_or_else(|| anyhow!("Tunnel not found"))?
        };
        stop_runtime_and_wait(&id);
        Ok(tunnel)
    })();
    if let Err(error) = &result {
        crate::app_log::log_error("tunnel.stop", error);
    }
    result
}

async fn run_tunnel(
    tunnel: TunnelConfig,
    credential: SshAuthCredential,
    stop_rx: oneshot::Receiver<()>,
    ready_tx: TunnelReadySender,
    done_tx: std_mpsc::Sender<()>,
    generation: u64,
) {
    let result = match tunnel.forward_type {
        TunnelForwardType::Local => {
            run_local_tunnel(tunnel.clone(), credential, stop_rx, ready_tx, generation).await
        }
        TunnelForwardType::Remote => {
            drop(ready_tx);
            run_remote_tunnel(tunnel.clone(), credential, stop_rx, generation).await
        }
    };
    if let Err(error) = result {
        crate::app_log::log_error("tunnel.runtime", &error);
    }
    // Only remove the entry if it is still the one we created. Otherwise a
    // slow-finishing old task would delete a runtime a newer start inserted.
    remove_runtime_if_generation(&tunnel.id, generation);
    let _ = done_tx.send(());
}

async fn run_local_tunnel(
    tunnel: TunnelConfig,
    credential: SshAuthCredential,
    mut stop_rx: oneshot::Receiver<()>,
    ready_tx: TunnelReadySender,
    generation: u64,
) -> Result<()> {
    let listen_address = format!("{}:{}", tunnel.listen_host, tunnel.listen_port);
    // Bind once and keep the listener for the whole runtime. Reconnects reuse
    // it, so they never race the OS for the local port.
    let listener = match TcpListener::bind(&listen_address).await {
        Ok(listener) => listener,
        Err(error) => {
            let message = format!(
                "Failed to bind local tunnel listener {listen_address}: {error}. \
                 The port may already be in use, or reserved by the OS (on Windows run \
                 `netsh interface ipv4 show excludedportrange protocol=tcp`); set the \
                 listen port to 0 to auto-assign a free port."
            );
            let _ = ready_tx.send(Err(message.clone()));
            return Err(anyhow!(message));
        }
    };
    let bound_port = listener
        .local_addr()
        .map(|address| address.port())
        .unwrap_or(tunnel.listen_port);
    update_runtime_listen_port(&tunnel.id, generation, bound_port);
    let _ = ready_tx.send(Ok(bound_port));

    let remote_routes = Arc::new(Mutex::new(HashMap::new()));
    let mut backoff = Duration::from_secs(1);
    let mut handle: Option<Arc<client::Handle<TunnelClientHandler>>> = None;
    // Shared with the relay tasks: a refused channel there means the same thing
    // as a refused probe here.
    let channel_open_failures = Arc::new(ChannelOpenFailures::new());
    // A rebuild triggered by refusals must not reset the backoff: that would
    // turn a target that is genuinely down into a reconnect every few seconds
    // instead of the intended 1→2→4→…→60s ramp.
    let mut forced_recycle = false;

    loop {
        // A session that refuses channels is not "closed", so the branch below
        // would reconnect forever and never actually reconnect. Drop it after
        // a run of refusals and let the normal path rebuild it.
        forced_recycle = false;
        if channel_open_failures.should_recycle() {
            if let Some(wedged) = handle.take() {
                forced_recycle = true;
                channel_open_failures.reset();
                let _ = tokio::time::timeout(
                    Duration::from_secs(2),
                    wedged.disconnect(Disconnect::ByApplication, "", "English"),
                )
                .await;
                crate::app_log::log_error_message(
                    "tunnel.local.session",
                    &format!(
                        "SSH session for tunnel \"{}\" refused {} channels in a row; \
                         recycling it",
                        tunnel.name, MAX_CHANNEL_OPEN_FAILURES
                    ),
                    None,
                );
            }
        }
        if handle.as_ref().is_none_or(|handle| handle.is_closed()) {
            if let Some(closed) = handle.take() {
                let _ = tokio::time::timeout(
                    Duration::from_secs(2),
                    closed.disconnect(Disconnect::ByApplication, "", "English"),
                )
                .await;
                crate::app_log::log_error_message(
                    "tunnel.local.session",
                    &format!(
                        "SSH session for tunnel \"{}\" closed; reconnecting",
                        tunnel.name
                    ),
                    None,
                );
            }
            update_runtime_status(&tunnel.id, generation, TunnelRuntimeStatus::Waiting);

            let connect = connect_ssh_profile(
                &tunnel.ssh_profile_id,
                credential.clone(),
                Arc::clone(&remote_routes),
            );
            tokio::pin!(connect);
            let connected = tokio::select! {
                _ = &mut stop_rx => return Ok(()),
                result = &mut connect => result,
            };
            match connected {
                Ok(new_handle) => {
                    handle = Some(Arc::new(new_handle));
                    if !forced_recycle {
                        backoff = Duration::from_secs(1);
                    }
                }
                Err(error) => {
                    crate::app_log::log_error("tunnel.local.connect", &error);
                    if sleep_or_stop(&mut stop_rx, backoff).await {
                        return Ok(());
                    }
                    backoff = next_backoff_delay(backoff);
                    continue;
                }
            }
        }

        let current = match handle.as_ref() {
            Some(handle) => Arc::clone(handle),
            None => continue,
        };

        let probe =
            remote_target_is_open_via_ssh(&current, &tunnel.target_host, tunnel.target_port);
        tokio::pin!(probe);
        let ready = tokio::select! {
            _ = &mut stop_rx => return Ok(()),
            ready = &mut probe => ready,
        };
        if !ready {
            channel_open_failures.record();
            update_runtime_status(&tunnel.id, generation, TunnelRuntimeStatus::Waiting);
            if sleep_or_stop(&mut stop_rx, backoff).await {
                return Ok(());
            }
            backoff = next_backoff_delay(backoff);
            continue;
        }
        // The probe opened a channel, so the session can still take them.
        channel_open_failures.reset();
        backoff = Duration::from_secs(1);
        update_runtime_status(&tunnel.id, generation, TunnelRuntimeStatus::Forwarding);

        // Set by a relay when the server refuses to open the forwarded channel
        // (usually the target program restarted). It moves us back to the
        // waiting/probe state instead of hammering a dead target.
        let unhealthy = Arc::new(AtomicBool::new(false));
        loop {
            if current.is_closed() || unhealthy.load(Ordering::Relaxed) {
                break;
            }
            tokio::select! {
                _ = &mut stop_rx => return Ok(()),
                _ = tokio::time::sleep(Duration::from_secs(2)) => {
                    if current.is_closed() || unhealthy.load(Ordering::Relaxed) {
                        break;
                    }
                }
                accepted = listener.accept() => {
                    let (stream, originator) = accepted?;
                    let connection_handle = Arc::clone(&current);
                    let connection_unhealthy = Arc::clone(&unhealthy);
                    let connection_failures = Arc::clone(&channel_open_failures);
                    let target_host = tunnel.target_host.clone();
                    let target_port = tunnel.target_port;
                    TOKIO_RUNTIME.spawn(async move {
                        if let Err(error) = handle_local_tunnel_connection(
                            connection_handle,
                            stream,
                            originator,
                            target_host,
                            target_port,
                        )
                        .await
                        {
                            let message = format!("{error:#}");
                            if is_channel_open_failure(&message) {
                                connection_unhealthy.store(true, Ordering::Relaxed);
                                connection_failures.record();
                            }
                            log_tunnel_connection_error("tunnel.local.connection", &error);
                        }
                    });
                }
            }
        }

        update_runtime_status(&tunnel.id, generation, TunnelRuntimeStatus::Waiting);
    }
}

async fn handle_local_tunnel_connection(
    handle: Arc<client::Handle<TunnelClientHandler>>,
    stream: TcpStream,
    originator: SocketAddr,
    target_host: String,
    target_port: u16,
) -> Result<()> {
    let channel = handle
        .channel_open_direct_tcpip(
            target_host,
            target_port.into(),
            originator.ip().to_string(),
            originator.port().into(),
        )
        .await
        .map_err(|error| anyhow!("Failed to open channel ({error:?})"))?;
    relay_tcp_stream_and_channel(stream, channel).await
}

async fn run_remote_tunnel(
    tunnel: TunnelConfig,
    credential: SshAuthCredential,
    mut stop_rx: oneshot::Receiver<()>,
    generation: u64,
) -> Result<()> {
    let remote_routes = Arc::new(Mutex::new(HashMap::new()));
    let mut backoff = Duration::from_secs(1);

    loop {
        update_runtime_status(&tunnel.id, generation, TunnelRuntimeStatus::Waiting);
        let connect = connect_ssh_profile(
            &tunnel.ssh_profile_id,
            credential.clone(),
            Arc::clone(&remote_routes),
        );
        tokio::pin!(connect);
        let connected = tokio::select! {
            _ = &mut stop_rx => return Ok(()),
            result = &mut connect => result,
        };
        let handle = match connected {
            Ok(handle) => handle,
            Err(error) => {
                crate::app_log::log_error("tunnel.remote.connect", &error);
                if sleep_or_stop(&mut stop_rx, backoff).await {
                    return Ok(());
                }
                backoff = next_backoff_delay(backoff);
                continue;
            }
        };
        backoff = Duration::from_secs(1);

        loop {
            if handle.is_closed() {
                break;
            }
            let probe = local_tcp_port_is_open(&tunnel.target_host, tunnel.target_port);
            tokio::pin!(probe);
            let ready = tokio::select! {
                _ = &mut stop_rx => return Ok(()),
                ready = &mut probe => ready,
            };
            if ready {
                break;
            }
            if sleep_or_stop(&mut stop_rx, backoff).await {
                return Ok(());
            }
            backoff = next_backoff_delay(backoff);
        }
        if handle.is_closed() {
            crate::app_log::log_error_message(
                "tunnel.remote.session",
                &format!(
                    "SSH session for tunnel \"{}\" closed; reconnecting",
                    tunnel.name
                ),
                None,
            );
            continue;
        }

        let requested_port = tunnel.listen_port;
        let route = RemoteRoute {
            target_host: tunnel.target_host.clone(),
            target_port: tunnel.target_port,
        };
        if requested_port != 0 {
            remote_routes.lock().unwrap().insert(
                remote_route_key(&tunnel.listen_host, requested_port),
                route.clone(),
            );
        }

        let forward = handle
            .tcpip_forward(tunnel.listen_host.clone(), requested_port.into())
            .await;
        let assigned_port = match forward {
            Ok(port) => port,
            Err(error) => {
                if requested_port != 0 {
                    remote_routes
                        .lock()
                        .unwrap()
                        .remove(&remote_route_key(&tunnel.listen_host, requested_port));
                }
                crate::app_log::log_error_message(
                    "tunnel.remote.forward",
                    &format!("Remote forward request failed: {error:?}"),
                    None,
                );
                if sleep_or_stop(&mut stop_rx, backoff).await {
                    return Ok(());
                }
                backoff = next_backoff_delay(backoff);
                continue;
            }
        };
        let active_port = if requested_port == 0 {
            u16::try_from(assigned_port).unwrap_or(0)
        } else {
            requested_port
        };
        let route_key = remote_route_key(&tunnel.listen_host, active_port);
        if requested_port == 0 {
            remote_routes
                .lock()
                .unwrap()
                .insert(route_key.clone(), route);
        }
        if active_port != 0 {
            update_runtime_listen_port(&tunnel.id, generation, active_port);
        }
        update_runtime_status(&tunnel.id, generation, TunnelRuntimeStatus::Forwarding);

        loop {
            if handle.is_closed() {
                break;
            }
            tokio::select! {
                _ = &mut stop_rx => {
                    remote_routes.lock().unwrap().remove(&route_key);
                    let _ = tokio::time::timeout(
                        Duration::from_secs(2),
                        handle.cancel_tcpip_forward(
                            tunnel.listen_host.clone(),
                            requested_port.into(),
                        ),
                    )
                    .await;
                    let _ = tokio::time::timeout(
                        Duration::from_secs(2),
                        handle.disconnect(Disconnect::ByApplication, "", "English"),
                    )
                    .await;
                    return Ok(());
                }
                _ = tokio::time::sleep(Duration::from_secs(2)) => {
                    if handle.is_closed() {
                        break;
                    }
                }
            }
        }

        remote_routes.lock().unwrap().remove(&route_key);
        update_runtime_status(&tunnel.id, generation, TunnelRuntimeStatus::Waiting);
        crate::app_log::log_error_message(
            "tunnel.remote.session",
            &format!(
                "SSH session for tunnel \"{}\" closed; reconnecting",
                tunnel.name
            ),
            None,
        );
    }
}

pub(crate) fn count_configs() -> usize {
    TUNNEL_STORE.lock().unwrap().configs.len()
}

pub(crate) fn count_running_runtimes() -> usize {
    RUNTIME_STORE.lock().unwrap().len()
}

pub(crate) fn shrink_stores_if_empty() {
    let mut store = TUNNEL_STORE.lock().unwrap();
    if store.configs.is_empty() {
        store.configs.shrink_to_fit();
    }
    let mut store = RUNTIME_STORE.lock().unwrap();
    if store.is_empty() {
        store.shrink_to_fit();
    }
}

#[cfg(test)]
fn clear_tunnels_for_test() -> std::sync::MutexGuard<'static, ()> {
    let guard = crate::test_support::WORKSPACE_LOCK.lock().unwrap();
    let mut store = TUNNEL_STORE.lock().unwrap();
    store.configs.clear();
    store.initialized = false;
    RUNTIME_STORE.lock().unwrap().clear();
    guard
}

#[cfg(test)]
mod tests {
    use std::{env, fs, path::Path, time::Duration};

    use super::*;
    use crate::{
        ssh_auth::{SshAuthCredential, SshConnectErrorCode},
        ssh_session::TOKIO_RUNTIME,
    };

    const ENCRYPTED_ED25519_KEY: &str = r#"-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABD1phlku5
A2G7Q9iP+DcOc9AAAAEAAAAAEAAAAzAAAAC3NzaC1lZDI1NTE5AAAAIHeLC1lWiCYrXsf/
85O/pkbUFZ6OGIt49PX3nw8iRoXEAAAAkKRF0st5ZI7xxo9g6A4m4l6NarkQre3mycqNXQ
dP3jryYgvsCIBAA5jMWSjrmnOTXhidqcOy4xYCrAttzSnZ/cUadfBenL+DQq6neffw7j8r
0tbCxVGp6yCQlKrgSZf6c0Hy7dNEIU2bJFGxLe6/kWChcUAt/5Ll5rI7DVQPJdLgehLzvv
sJWR7W+cGvJ/vLsw==
-----END OPENSSH PRIVATE KEY-----"#;

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

        fn config_path(&self) -> std::path::PathBuf {
            self.path().join("config").join("tunnels.yaml")
        }
    }

    impl Drop for TestWorkspace {
        fn drop(&mut self) {
            env::set_current_dir(&self.original_dir).unwrap();
        }
    }

    fn reset_store() {
        let mut store = TUNNEL_STORE.lock().unwrap();
        store.configs.clear();
        store.initialized = false;
        RUNTIME_STORE.lock().unwrap().clear();
    }

    #[test]
    fn exponential_backoff_caps_at_sixty_seconds() {
        assert_eq!(
            next_backoff_delay(Duration::from_secs(1)),
            Duration::from_secs(2)
        );
        assert_eq!(
            next_backoff_delay(Duration::from_secs(2)),
            Duration::from_secs(4)
        );
        assert_eq!(
            next_backoff_delay(Duration::from_secs(32)),
            Duration::from_secs(60)
        );
        assert_eq!(
            next_backoff_delay(Duration::from_secs(60)),
            Duration::from_secs(60)
        );
    }

    #[test]
    fn local_tcp_port_check_reports_open_and_closed_ports() {
        let _guard = clear_tunnels_for_test();
        let _workspace = TestWorkspace::new();

        TOKIO_RUNTIME.block_on(async {
            let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
            let port = listener.local_addr().unwrap().port();
            let accept_task = TOKIO_RUNTIME.spawn(async move {
                let _ = listener.accept().await;
            });

            assert!(local_tcp_port_is_open("127.0.0.1", port).await);
            accept_task.abort();
            assert!(!local_tcp_port_is_open("127.0.0.1", 1).await);
        });
    }

    #[test]
    fn remote_route_key_uses_listen_host_and_port() {
        assert_eq!(remote_route_key("0.0.0.0", 19090), "0.0.0.0:19090");
    }

    #[test]
    fn stopping_missing_tunnel_returns_error() {
        let _guard = clear_tunnels_for_test();
        let _workspace = TestWorkspace::new();
        reset_store();

        let result = stop_tunnel("missing".to_string());

        assert!(result.is_err());
    }

    #[test]
    fn creates_tunnel_yaml_without_runtime_status() {
        let _guard = clear_tunnels_for_test();
        let workspace = TestWorkspace::new();
        reset_store();

        let created = create_tunnel(
            "Dev API".to_string(),
            TunnelForwardType::Local,
            "profile-1".to_string(),
            "127.0.0.1".to_string(),
            18080,
            "127.0.0.1".to_string(),
            8080,
        )
        .unwrap();

        let yaml = fs::read_to_string(workspace.config_path()).unwrap();
        assert!(!created.id.is_empty());
        assert_eq!(created.status, TunnelRuntimeStatus::Stopped);
        assert!(yaml.contains("tunnels:"));
        assert!(yaml.contains(&format!("id: {}", created.id)));
        assert!(yaml.contains("name: Dev API"));
        assert!(yaml.contains("forward_type: local"));
        assert!(yaml.contains("ssh_profile_id: profile-1"));
        assert!(yaml.contains("listen_host: 127.0.0.1"));
        assert!(yaml.contains("listen_port: 18080"));
        assert!(yaml.contains("target_host: 127.0.0.1"));
        assert!(yaml.contains("target_port: 8080"));
        assert!(!yaml.contains("status:"));
    }

    #[test]
    fn updates_and_deletes_tunnel_yaml_by_id() {
        let _guard = clear_tunnels_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        let created = create_tunnel(
            "Dev API".to_string(),
            TunnelForwardType::Local,
            "profile-1".to_string(),
            "127.0.0.1".to_string(),
            18080,
            "127.0.0.1".to_string(),
            8080,
        )
        .unwrap();

        let updated = update_tunnel(
            created.id.clone(),
            "Webhook".to_string(),
            TunnelForwardType::Remote,
            "profile-2".to_string(),
            "0.0.0.0".to_string(),
            19090,
            "127.0.0.1".to_string(),
            9090,
        )
        .unwrap();
        assert_eq!(updated.id, created.id);
        assert_eq!(updated.forward_type, TunnelForwardType::Remote);

        let yaml = fs::read_to_string(workspace.config_path()).unwrap();
        assert!(yaml.contains("name: Webhook"));
        assert!(yaml.contains("forward_type: remote"));
        assert!(!yaml.contains("Dev API"));

        delete_tunnel(created.id).unwrap();
        let yaml = fs::read_to_string(workspace.config_path()).unwrap();
        assert!(!yaml.contains("Webhook"));
    }

    #[test]
    fn list_tunnels_combines_persisted_configs_with_runtime_status() {
        let _guard = clear_tunnels_for_test();
        let _workspace = TestWorkspace::new();
        reset_store();
        let created = create_tunnel(
            "Dev API".to_string(),
            TunnelForwardType::Local,
            "profile-1".to_string(),
            "127.0.0.1".to_string(),
            18080,
            "127.0.0.1".to_string(),
            8080,
        )
        .unwrap();
        set_runtime_status(&created.id, TunnelRuntimeStatus::Waiting);

        let tunnels = list_tunnels().unwrap();

        assert_eq!(tunnels.len(), 1);
        assert_eq!(tunnels[0].status, TunnelRuntimeStatus::Waiting);
    }

    #[test]
    fn expected_connection_close_filters_client_resets_only() {
        assert!(is_expected_connection_close(
            "你的主机中的软件中止了一个已建立的连接。 (os error 10053)"
        ));
        assert!(is_expected_connection_close("Connection reset by peer"));
        assert!(!is_expected_connection_close(
            "Failed to open channel (ConnectFailed)"
        ));
    }

    #[test]
    fn runtime_status_overlays_auto_assigned_listen_port() {
        let _guard = clear_tunnels_for_test();
        let _workspace = TestWorkspace::new();
        reset_store();
        let created = create_tunnel(
            "Auto Port".to_string(),
            TunnelForwardType::Local,
            "profile-1".to_string(),
            "127.0.0.1".to_string(),
            0,
            "127.0.0.1".to_string(),
            8080,
        )
        .unwrap();
        RUNTIME_STORE.lock().unwrap().insert(
            created.id.clone(),
            TunnelRuntime {
                generation: 7,
                status: TunnelRuntimeStatus::Forwarding,
                active_listen_port: Some(52345),
                stop_tx: None,
                done_rx: None,
            },
        );

        let tunnels = list_tunnels().unwrap();

        assert_eq!(tunnels[0].listen_port, 52345);
        assert_eq!(tunnels[0].status, TunnelRuntimeStatus::Forwarding);
    }

    #[test]
    fn stale_runtime_generation_does_not_remove_newer_runtime() {
        let _guard = clear_tunnels_for_test();
        let _workspace = TestWorkspace::new();
        reset_store();
        let created = create_tunnel(
            "Race".to_string(),
            TunnelForwardType::Local,
            "profile-1".to_string(),
            "127.0.0.1".to_string(),
            18080,
            "127.0.0.1".to_string(),
            8080,
        )
        .unwrap();
        RUNTIME_STORE.lock().unwrap().insert(
            created.id.clone(),
            TunnelRuntime {
                generation: 2,
                status: TunnelRuntimeStatus::Waiting,
                active_listen_port: None,
                stop_tx: None,
                done_rx: None,
            },
        );

        remove_runtime_if_generation(&created.id, 1);
        assert!(RUNTIME_STORE.lock().unwrap().contains_key(&created.id));

        remove_runtime_if_generation(&created.id, 2);
        assert!(!RUNTIME_STORE.lock().unwrap().contains_key(&created.id));
    }

    #[test]
    fn encrypted_private_key_tunnel_start_returns_passphrase_required() {
        let _guard = clear_tunnels_for_test();
        let workspace = TestWorkspace::new();
        reset_store();
        let key_path = workspace.path().join("id_ed25519");
        fs::write(&key_path, ENCRYPTED_ED25519_KEY).unwrap();
        let tunnel = create_tunnel(
            "Dev API".to_string(),
            TunnelForwardType::Local,
            "profile-1".to_string(),
            "127.0.0.1".to_string(),
            18080,
            "127.0.0.1".to_string(),
            8080,
        )
        .unwrap();

        let result = start_tunnel(
            tunnel.id.clone(),
            SshAuthCredential {
                password: None,
                private_key_path: Some(key_path.to_string_lossy().to_string()),
                passphrase: None,
            },
        )
        .unwrap();

        assert!(result.tunnel.is_none());
        assert_eq!(
            result.error.unwrap().code,
            SshConnectErrorCode::PassphraseRequired
        );
        assert!(!RUNTIME_STORE.lock().unwrap().contains_key(&tunnel.id));
    }

    /// A live SSH session that has stopped accepting channels reports neither
    /// "closed" nor a broken pipe — it just answers every channel open with
    /// `ConnectFailed`. Without this run-length check the tunnel keeps its
    /// listener bound, stops accepting, and only recovers on a restart.
    #[test]
    fn channel_open_failures_trip_after_three_in_a_row() {
        let failures = ChannelOpenFailures::new();
        assert!(!failures.should_recycle());

        failures.record();
        assert!(!failures.should_recycle());
        failures.record();
        assert!(!failures.should_recycle());

        failures.record();
        assert!(failures.should_recycle());
    }

    /// One refusal is normal: the target may genuinely be restarting. A probe
    /// that succeeds afterwards opens a channel, so the session is healthy and
    /// the run restarts.
    #[test]
    fn a_successful_probe_clears_the_run() {
        let failures = ChannelOpenFailures::new();
        failures.record();
        failures.record();
        failures.reset();

        assert!(!failures.should_recycle());
        failures.record();
        assert!(!failures.should_recycle());
    }

    #[test]
    fn channel_open_failure_messages_are_recognised() {
        assert!(is_channel_open_failure(
            "Failed to open channel (ChannelOpenFailure(ConnectFailed))"
        ));
        assert!(!is_channel_open_failure("Broken pipe (os error 32)"));
    }
}
