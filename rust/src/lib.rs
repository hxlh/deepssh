#![allow(unexpected_cfgs)]

#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

pub(crate) mod app_log;
pub mod config_path;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
pub mod local_terminal;
pub mod profile;
pub mod ssh_auth;
pub mod ssh_session;
pub mod theme;
pub mod tunnel;

#[cfg(test)]
pub(crate) mod test_support {
    use std::sync::Mutex;

    use once_cell::sync::Lazy;

    pub(crate) static WORKSPACE_LOCK: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));
}
