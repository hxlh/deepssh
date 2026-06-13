// DeepSSH 版本信息和滚动修复标识

/// 滚动修复版本标识
/// 如果你在终端中看到这个版本号，说明修复已经包含在构建中
const String kScrollFixVersion = '1.0.0-scroll-fix';
const String kScrollFixCommit = '7e194a7';
const String kScrollFixDate = '2026-06-13';

/// 检查修复是否已应用
class ScrollFixInfo {
  static const bool isApplied = true;
  static const int scrollbackLines = 50000;

  static void printInfo() {
    print('DeepSSH Scroll Fix Information');
    print('==============================');
    print('Version: $kScrollFixVersion');
    print('Commit: $kScrollFixCommit');
    print('Date: $kScrollFixDate');
    print('Scrollback Lines: $scrollbackLines');
    print('Fix Applied: $isApplied');
    print('');
    print('Key Features:');
    print('  ✓ InfiniteScrollView alt buffer double-check');
    print('  ✓ Increased scrollback buffer (10k → 50k)');
    print('  ✓ Debug utilities (Ctrl+Shift+D)');
    print('==============================');
  }
}
