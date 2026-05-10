#![allow(unexpected_cfgs)]

use std::alloc::{GlobalAlloc, Layout};
use std::sync::Once;

// Wraps `mimalloc::MiMalloc` so that the first allocation triggers our tunables.
// Doing it here (rather than from a Dart-side init call) makes sure mimalloc
// uses the smaller arena from the very first byte, before FRB or tokio touch
// the heap.
struct ConfiguredMiMalloc;

unsafe impl GlobalAlloc for ConfiguredMiMalloc {
    #[inline]
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        ensure_mimalloc_configured();
        mimalloc::MiMalloc.alloc(layout)
    }

    #[inline]
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        mimalloc::MiMalloc.dealloc(ptr, layout)
    }

    #[inline]
    unsafe fn alloc_zeroed(&self, layout: Layout) -> *mut u8 {
        ensure_mimalloc_configured();
        mimalloc::MiMalloc.alloc_zeroed(layout)
    }

    #[inline]
    unsafe fn realloc(&self, ptr: *mut u8, layout: Layout, new_size: usize) -> *mut u8 {
        mimalloc::MiMalloc.realloc(ptr, layout, new_size)
    }
}

#[global_allocator]
static GLOBAL: ConfiguredMiMalloc = ConfiguredMiMalloc;

#[inline]
fn ensure_mimalloc_configured() {
    static INIT: Once = Once::new();
    INIT.call_once(configure_mimalloc);
}

#[cold]
fn configure_mimalloc() {
    // libmimalloc-sys 0.1.47 only re-exports a handful of mi_option_t values
    // and leaves out the ones we actually need. Hard-coding the v3 enum
    // offsets here (mimalloc.h v3 ordering with `_mi_option_last = 46`).
    // If we ever bump libmimalloc-sys major or flip the `v2` feature, these
    // need to be re-checked against `c_src/mimalloc/v3/include/mimalloc.h`.
    use libmimalloc_sys::{mi_option_set, mi_option_t};
    const MI_OPTION_ARENA_EAGER_COMMIT: mi_option_t = 4;
    const MI_OPTION_PURGE_DECOMMITS: mi_option_t = 5;
    const MI_OPTION_PURGE_DELAY: mi_option_t = 15;
    const MI_OPTION_ARENA_RESERVE: mi_option_t = 23;
    const MI_OPTION_PAGE_FULL_RETAIN: mi_option_t = 36;
    const MI_OPTION_PAGEMAP_COMMIT: mi_option_t = 39;
    const MI_OPTION_PAGE_MAX_RECLAIM: mi_option_t = 41;

    unsafe {
        // Don't eagerly commit physical pages when reserving an arena's
        // virtual range. Default is 2 (auto-detect on overcommit OSes); 0 is
        // explicit "lazy commit on first touch", which keeps RSS down on a
        // mostly-idle SSH client.
        mi_option_set(MI_OPTION_ARENA_EAGER_COMMIT, 0);
        // Cap each arena reservation at 16 MiB (default ~128 MiB on Win64,
        // 1 GiB on Linux64). Value is in KiB. Mostly cosmetic for committed
        // RSS, but keeps virtual size sane and lets pressure-driven extra
        // arenas be small.
        mi_option_set(MI_OPTION_ARENA_RESERVE, 16 * 1024);
        // Return unused pages to the OS after 100 ms idle (default 1000 ms is
        // too lazy for an interactive UI; we want quick reclaim after a flood
        // of search output is consumed).
        mi_option_set(MI_OPTION_PURGE_DELAY, 100);
        // Decommit (truly release physical pages) instead of just MEM_RESET-ing.
        mi_option_set(MI_OPTION_PURGE_DECOMMITS, 1);
        // Don't retain any full pages per size class on free. Default is 2,
        // which keeps two cached pages per class as a hot allocation reserve.
        // We're an idle-most-of-the-time UI, not a hot-path allocator — give
        // the memory back instead.
        mi_option_set(MI_OPTION_PAGE_FULL_RETAIN, 0);
        // Cap per-size-class page hoarding at 4 (default -1 = unlimited). When
        // a tokio worker tears down, mimalloc may keep pages around forever
        // "in case" the next worker uses the same size class.
        mi_option_set(MI_OPTION_PAGE_MAX_RECLAIM, 4);
        // Skip the upfront pagemap commit on Windows (default 1 there). Saves
        // a chunk of committed RSS at startup; the pagemap commits on demand
        // once we touch the address.
        mi_option_set(MI_OPTION_PAGEMAP_COMMIT, 0);
    }
}

pub(crate) mod app_log;
pub mod config_path;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
pub mod local_terminal;
pub mod mem_metrics;
pub mod profile;
pub mod ssh_auth;
pub mod ssh_session;
pub mod theme;
pub mod tunnel;

// Best-effort hint to mimalloc to scan idle pages and decommit them. Only
// fires when every session store is empty so the purge happens on the
// 1→0 transition rather than after each individual close. Uses the
// aggressive variant (`force=true`) so abandoned segments held by torn-down
// tokio workers also get reclaimed, not just pages already marked purgeable.
// On Windows we follow up with `EmptyWorkingSet`: mimalloc decommit alone
// only tells the kernel pages are unused, the working set still shows them
// until pressure hits. EmptyWorkingSet forces the OS to trim immediately,
// which is what makes RSS in Task Manager actually drop.
pub(crate) fn collect_idle_pages_if_drained() {
    if ssh_session::count_sessions() == 0
        && ssh_session::count_connections() == 0
        && ssh_session::count_clients() == 0
        && local_terminal::count_sessions() == 0
    {
        unsafe { libmimalloc_sys::mi_collect(true) };
        #[cfg(windows)]
        empty_working_set();
    }
}

#[cfg(windows)]
fn empty_working_set() {
    use windows_sys::Win32::System::ProcessStatus::EmptyWorkingSet;
    use windows_sys::Win32::System::Threading::GetCurrentProcess;
    // SAFETY: GetCurrentProcess returns a pseudo-handle with PROCESS_ALL_ACCESS
    // for the current process; passing it to EmptyWorkingSet is the documented
    // pattern. Return value is ignored — failure here is non-fatal.
    unsafe {
        let _ = EmptyWorkingSet(GetCurrentProcess());
    }
}

#[cfg(test)]
pub(crate) mod test_support {
    use std::sync::Mutex;

    use once_cell::sync::Lazy;

    pub(crate) static WORKSPACE_LOCK: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));
}
