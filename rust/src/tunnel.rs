use std::{
    collections::HashMap,
    fs,
    net::SocketAddr,
    sync::{Arc, Mutex},
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

#[flutter_rust_bridge::frb(ignore)]
struct TunnelRuntime {
    status: TunnelRuntimeStatus,
    stop_tx: Option<oneshot::Sender<()>>,
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
        if let Some(route) = route {
            TOKIO_RUNTIME.spawn(async move {
                match TcpStream::connect(format!("{}:{}", route.target_host, route.target_port))
                    .await
                {
                    Ok(stream) => {
                        if let Err(error) = relay_tcp_stream_and_channel(stream, channel).await {
                            crate::app_log::log_error("tunnel.remote.connection", &error);
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
    config.status = runtime_status(&config.id);
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
            status,
            stop_tx: None,
        });
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
    config.keepalive_interval = Some(Duration::from_secs(30));
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
    loop {
        tokio::select! {
            read = reader.read(&mut buf), if !stream_closed => {
                match read {
                    Ok(0) => {
                        stream_closed = true;
                        channel.eof().await?;
                    }
                    Ok(n) => channel.data(&buf[..n]).await?,
                    Err(error) => return Err(error.into()),
                }
            }
            message = channel.wait() => {
                match message {
                    Some(ChannelMsg::Data { data }) => writer.write_all(&data).await?,
                    Some(ChannelMsg::ExtendedData { data, .. }) => writer.write_all(&data).await?,
                    Some(ChannelMsg::Eof) | Some(ChannelMsg::Close) | None => {
                        if !stream_closed {
                            let _ = channel.eof().await;
                        }
                        break;
                    }
                    _ => {}
                }
            }
        }
    }
    Ok(())
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
            let _ = channel.eof().await;
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
        if let Some(mut runtime) = RUNTIME_STORE.lock().unwrap().remove(&id) {
            if let Some(stop_tx) = runtime.stop_tx.take() {
                let _ = stop_tx.send(());
            }
        }
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

        let (stop_tx, stop_rx) = oneshot::channel::<()>();
        RUNTIME_STORE.lock().unwrap().insert(
            id.clone(),
            TunnelRuntime {
                status: TunnelRuntimeStatus::Waiting,
                stop_tx: Some(stop_tx),
            },
        );

        TOKIO_RUNTIME.spawn(run_tunnel(tunnel.clone(), credential, stop_rx));
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
        if let Some(mut runtime) = RUNTIME_STORE.lock().unwrap().remove(&id) {
            if let Some(stop_tx) = runtime.stop_tx.take() {
                let _ = stop_tx.send(());
            }
        }
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
) {
    let result = match tunnel.forward_type {
        TunnelForwardType::Local => run_local_tunnel(tunnel.clone(), credential, stop_rx).await,
        TunnelForwardType::Remote => run_remote_tunnel(tunnel.clone(), credential, stop_rx).await,
    };
    if let Err(error) = result {
        crate::app_log::log_error("tunnel.runtime", &error);
    }
    RUNTIME_STORE.lock().unwrap().remove(&tunnel.id);
}

async fn run_local_tunnel(
    tunnel: TunnelConfig,
    credential: SshAuthCredential,
    mut stop_rx: oneshot::Receiver<()>,
) -> Result<()> {
    let remote_routes = Arc::new(Mutex::new(HashMap::new()));
    let handle = Arc::new(
        connect_ssh_profile(
            &tunnel.ssh_profile_id,
            credential,
            Arc::clone(&remote_routes),
        )
        .await?,
    );
    let mut backoff = Duration::from_secs(1);

    loop {
        tokio::select! {
            _ = &mut stop_rx => return Ok(()),
            ready = remote_target_is_open_via_ssh(&handle, &tunnel.target_host, tunnel.target_port) => {
                if ready {
                    break;
                }
                set_runtime_status(&tunnel.id, TunnelRuntimeStatus::Waiting);
                tokio::time::sleep(backoff).await;
                backoff = next_backoff_delay(backoff);
            }
        }
    }

    let listener = TcpListener::bind(format!("{}:{}", tunnel.listen_host, tunnel.listen_port))
        .await
        .with_context(|| {
            format!(
                "Failed to bind local tunnel listener {}:{}",
                tunnel.listen_host, tunnel.listen_port
            )
        })?;
    set_runtime_status(&tunnel.id, TunnelRuntimeStatus::Forwarding);

    loop {
        tokio::select! {
            _ = &mut stop_rx => break,
            accepted = listener.accept() => {
                let (stream, originator) = accepted?;
                let handle = Arc::clone(&handle);
                let target_host = tunnel.target_host.clone();
                let target_port = tunnel.target_port;
                TOKIO_RUNTIME.spawn(async move {
                    if let Err(error) = handle_local_tunnel_connection(
                        handle,
                        stream,
                        originator,
                        target_host,
                        target_port,
                    ).await {
                        crate::app_log::log_error("tunnel.local.connection", &error);
                    }
                });
            }
        }
    }
    let _ = handle
        .disconnect(Disconnect::ByApplication, "", "English")
        .await;
    Ok(())
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
        .await?;
    relay_tcp_stream_and_channel(stream, channel).await
}

async fn run_remote_tunnel(
    tunnel: TunnelConfig,
    credential: SshAuthCredential,
    mut stop_rx: oneshot::Receiver<()>,
) -> Result<()> {
    let remote_routes = Arc::new(Mutex::new(HashMap::new()));
    let handle = connect_ssh_profile(
        &tunnel.ssh_profile_id,
        credential,
        Arc::clone(&remote_routes),
    )
    .await?;
    let mut backoff = Duration::from_secs(1);

    loop {
        tokio::select! {
            _ = &mut stop_rx => return Ok(()),
            ready = local_tcp_port_is_open(&tunnel.target_host, tunnel.target_port) => {
                if ready {
                    break;
                }
                set_runtime_status(&tunnel.id, TunnelRuntimeStatus::Waiting);
                tokio::time::sleep(backoff).await;
                backoff = next_backoff_delay(backoff);
            }
        }
    }

    let route_key = remote_route_key(&tunnel.listen_host, tunnel.listen_port);
    remote_routes.lock().unwrap().insert(
        route_key.clone(),
        RemoteRoute {
            target_host: tunnel.target_host.clone(),
            target_port: tunnel.target_port,
        },
    );

    handle
        .tcpip_forward(tunnel.listen_host.clone(), tunnel.listen_port.into())
        .await
        .map_err(|e| anyhow!("Remote forward request failed: {:?}", e))?;
    set_runtime_status(&tunnel.id, TunnelRuntimeStatus::Forwarding);

    let _ = (&mut stop_rx).await;
    remote_routes.lock().unwrap().remove(&route_key);
    let _ = handle
        .cancel_tcpip_forward(tunnel.listen_host.clone(), tunnel.listen_port.into())
        .await;
    let _ = handle
        .disconnect(Disconnect::ByApplication, "", "English")
        .await;
    Ok(())
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
}
