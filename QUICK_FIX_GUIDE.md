# 🎯 DeepSSH 滚动修复 - 快速指南

## 问题
在 DeepSSH 中运行 Claude Code 时：
- ❌ 无法滚动长输出
- ❌ 出现大量下划线

## 解决方案
已应用 3 个关键修复，解决了 `InfiniteScrollView` 滚动冲突问题。

## ✅ 验证修复

```bash
cd /home/hxlh/data/project/deepssh
bash verify_fix.sh
```

## 🚀 测试

```bash
# 1. 构建并运行
flutter pub get
flutter run -d linux

# 2. 在终端中测试滚动
yes "Test line" | head -20000

# 3. 测试 Claude Code
claude
> "生成一个很长的回答"
```

## 📋 变更内容

### 核心修复
1. **scroll_handler.dart**: 防止 InfiniteScrollView 干扰正常滚动
2. **theme_settings.dart**: 滚动缓冲区 10000 → 50000 行
3. **terminal_debugger.dart**: 新增调试工具

### 技术原理
- `InfiniteScrollView` 设置 `maxScrollExtent = ∞`
- 只应在 alternate buffer（vim/less）时使用
- Claude Code 运行在普通模式，需要正常滚动
- 添加双重检查确保隔离

## 📚 详细文档

- **完整修复说明**: `SCROLLING_FIX_SUMMARY.md`
- **技术分析**: `docs/SCROLLING_ISSUE_ANALYSIS.md`
- **实施指南**: `docs/CLAUDE_CODE_FIX.md`

## 🐛 如果仍有问题

启用调试日志：
```dart
// lib/main.dart
import 'features/terminal/terminal_debugger.dart';

void main() {
  if (kDebugMode) {
    TerminalDebugger.enableDebugLogs = true;
  }
  runApp(MyApp());
}
```

查看控制台输出中的滚动和终端状态信息。

## 📝 提交建议

```bash
git add -A
git commit -m "fix(terminal): resolve Claude Code scrolling issues

- Fix InfiniteScrollView interfering with normal scrollback
- Increase scrollbackLines to 50000
- Add debugging utilities"
```

---

**状态**: ✅ 修复已应用并验证  
**日期**: 2026-06-13
