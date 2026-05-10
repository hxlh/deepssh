//! Cross-layer memory metrics surfaced to the Flutter UI.
//!
//! The single public entry point is [`rust_mem_snapshot`]: it reads
//! `mi_process_info` for OS-level RSS, captures `mi_stats_print_out`
//! into a string, and reads the per-feature registry sizes via the
//! `count_*` helpers in `local_terminal`, `ssh_session`, and `tunnel`.

use std::ffi::{c_void, CStr};
use std::os::raw::c_char;

use libmimalloc_sys::{mi_collect, mi_process_info, mi_stats_print_out};

#[derive(Clone, Debug)]
pub struct RustMemSnapshot {
    pub current_rss: u64,
    pub peak_rss: u64,
    pub current_commit: u64,
    pub peak_commit: u64,
    pub page_faults: u64,
    pub elapsed_ms: u64,
    pub user_ms: u64,
    pub system_ms: u64,
    pub ssh_sessions: u64,
    pub ssh_connections: u64,
    pub ssh_clients: u64,
    pub local_terminals: u64,
    pub tunnel_configs: u64,
    pub tunnels_running: u64,
    pub mimalloc_stats_text: String,
}

unsafe extern "C" fn capture_stats(msg: *const c_char, arg: *mut c_void) {
    if msg.is_null() || arg.is_null() {
        return;
    }
    // SAFETY: caller passes &mut String as *mut c_void; valid for the duration
    // of mi_stats_print_out, which is a synchronous call.
    let target = &mut *(arg as *mut String);
    let cstr = CStr::from_ptr(msg);
    if let Ok(s) = cstr.to_str() {
        target.push_str(s);
    }
}

fn collect_mimalloc_stats() -> String {
    let mut buf = String::new();
    // SAFETY: capture_stats only writes through the &mut String we pass.
    unsafe {
        mi_stats_print_out(Some(capture_stats), &mut buf as *mut String as *mut c_void);
    }
    buf
}

fn collect_process_info() -> (u64, u64, u64, u64, u64, u64, u64, u64) {
    let mut elapsed: usize = 0;
    let mut user: usize = 0;
    let mut system: usize = 0;
    let mut current_rss: usize = 0;
    let mut peak_rss: usize = 0;
    let mut current_commit: usize = 0;
    let mut peak_commit: usize = 0;
    let mut page_faults: usize = 0;
    // SAFETY: all out-pointers reference local stack variables we own.
    unsafe {
        mi_process_info(
            &mut elapsed,
            &mut user,
            &mut system,
            &mut current_rss,
            &mut peak_rss,
            &mut current_commit,
            &mut peak_commit,
            &mut page_faults,
        );
    }
    (
        elapsed as u64,
        user as u64,
        system as u64,
        current_rss as u64,
        peak_rss as u64,
        current_commit as u64,
        peak_commit as u64,
        page_faults as u64,
    )
}

pub fn rust_mem_snapshot() -> RustMemSnapshot {
    let (
        elapsed_ms,
        user_ms,
        system_ms,
        current_rss,
        peak_rss,
        current_commit,
        peak_commit,
        page_faults,
    ) = collect_process_info();

    RustMemSnapshot {
        current_rss,
        peak_rss,
        current_commit,
        peak_commit,
        page_faults,
        elapsed_ms,
        user_ms,
        system_ms,
        ssh_sessions: crate::ssh_session::count_sessions() as u64,
        ssh_connections: crate::ssh_session::count_connections() as u64,
        ssh_clients: crate::ssh_session::count_clients() as u64,
        local_terminals: crate::local_terminal::count_sessions() as u64,
        tunnel_configs: crate::tunnel::count_configs() as u64,
        tunnels_running: crate::tunnel::count_running_runtimes() as u64,
        mimalloc_stats_text: collect_mimalloc_stats(),
    }
}

pub fn rust_mimalloc_collect() {
    // SAFETY: mi_collect is documented as thread-safe.
    unsafe {
        mi_collect(true);
    }
    // Mirror the same EmptyWorkingSet trick used by the auto-drain hook so
    // pressing "Mimalloc Collect" in the diagnostics UI gives the user the
    // same RSS drop they'd see after closing all sessions.
    #[cfg(windows)]
    unsafe {
        use windows_sys::Win32::System::ProcessStatus::EmptyWorkingSet;
        use windows_sys::Win32::System::Threading::GetCurrentProcess;
        let _ = EmptyWorkingSet(GetCurrentProcess());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn snapshot_reports_nonzero_rss_and_includes_stats_text() {
        let snap = rust_mem_snapshot();
        assert!(snap.current_rss > 0, "rss should be > 0, got {}", snap.current_rss);
        assert!(snap.peak_rss >= snap.current_rss);
        assert!(!snap.mimalloc_stats_text.is_empty());
    }

    #[test]
    fn collect_does_not_panic() {
        rust_mimalloc_collect();
    }
}
