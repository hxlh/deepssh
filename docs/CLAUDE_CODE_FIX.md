# DeepSSH Claude Code 渲染问题修复

## 问题总结

在 DeepSSH 中运行 Claude Code 时遇到：
1. **无法滚动**：内容过长时终端窗口无法滚动
2. **下划线过多**：输出中出现大量下划线

## 已应用的修复

### 1. 修复滚动问题

**修改文件**：`third_party/xterm/lib/src/ui/scroll_handler.dart`

**问题根源**：
- `InfiniteScrollView` 在非 alternate buffer 模式下被错误激活
- 它设置了 `applyContentDimensions(double.negativeInfinity, double.infinity)`
- 导致 Flutter 的 `ScrollController` 认为内容是无限的，滚动失效

**修复方案**：
```dart
@override
Widget build(BuildContext context) {
  // 只有在真正的 alternate buffer 模式下才使用 InfiniteScrollView
  // 这防止无限滚动干扰正常的 scrollback buffer 滚动
  if (!isAltBuffer || !widget.terminal.isUsingAltBuffer) {
    return widget.child;
  }
  // ...
}
```

**原理**：
- `isAltBuffer` 是状态追踪变量
- `widget.terminal.isUsingAltBuffer` 是实时终端状态
- 双重检查确保只在 vim/less 等全屏应用中使用无限滚动
- Claude Code 运行在普通模式下，会使用正常的有限滚动

### 2. 增加滚动缓冲区

**修改文件**：`lib/core/models/theme_settings.dart`

**修改**：将所有主题预设的 `scrollbackLines` 从 `10000` 增加到 `50000`

**原因**：
- Claude Code 输出通常很长（数千到上万行）
- 10000 行缓冲可能不够
- 50000 行可以覆盖大部分使用场景
- 内存占用增加约 40MB（可接受）

**影响的预设**：
- Command Deck
- One Dark
- Solarized

### 3. 添加调试工具

**新文件**：`lib/features/terminal/terminal_debugger.dart`

**功能**：
```dart
// 启用调试日志
TerminalDebugger.enableDebugLogs = true;

// 检查滚动状态
TerminalDebugger.checkScrollPosition(controller, 'context');

// 检查终端状态
TerminalDebugger.checkTerminalState(terminal, 'context');

// 分析 ANSI 序列
TerminalDebugger.logAnsiStatistics(text, 'context');
```

**用途**：
- 诊断滚动问题
- 分析 ANSI 转义序列（包括下划线）
- 监控终端 buffer 状态

## 下划线问题分析

### 可能的原因

1. **Claude Code 的格式化输出**
   - Claude Code 使用 markdown 渲染
   - 可能使用 ANSI 序列 `\e[4m` 来实现下划线
   - 在某些情况下可能没有正确重置（`\e[24m` 或 `\e[0m`）

2. **终端渲染逻辑**
   - xterm.dart 正确实现了下划线渲染
   - 如果 ANSI 序列不平衡，下划线会"泄漏"到后续文本

3. **诊断步骤**

启用调试日志并运行 Claude Code：
```dart
// 在 main.dart 或启动时设置
TerminalDebugger.enableDebugLogs = true;
```

查看日志中的 ANSI 序列统计：
```
[context] ANSI Sequences:
  - Underline: 150 times
  - Reset: 120 times
  - Not underlined: 10 times
  ⚠️  WARNING: More underline-on than underline-off!
```

### 临时解决方案

如果下划线仍然过多，可以考虑：

**选项 1：在 xterm painter 中禁用下划线**（不推荐）
```dart
// third_party/xterm/lib/src/ui/painter.dart:217
underline: false,  // 强制禁用
```

**选项 2：在写入时过滤 ANSI 序列**（推荐用于测试）
```dart
// 在 terminal.write() 之前
final cleanText = text.replaceAll(RegExp(r'\x1b\[4m'), '');  // 移除下划线
terminal.write(cleanText);
```

**选项 3：联系 Claude Code 团队**
如果确认是 Claude Code 的输出问题，可以报告给 Anthropic。

## 测试验证

### 1. 测试滚动

```bash
# 在 DeepSSH 中连接到本地终端或 SSH
# 运行一个生成大量输出的命令
yes "Test line $(date)" | head -20000

# 验证：
# - 可以使用鼠标滚轮滚动
# - 滚动条可见且可拖动
# - 可以滚动到顶部和底部
```

### 2. 测试 Claude Code

```bash
# 在 DeepSSH 终端中运行 Claude Code
claude

# 让它生成长输出
# 例如："请详细解释 Rust 的所有权系统"

# 验证：
# - 输出完成后可以滚动查看
# - 下划线只出现在应该有的地方
# - 滚动条正常工作
```

### 3. 启用调试日志

在 Flutter 代码中临时启用：
```dart
// lib/main.dart 或 workbench_page.dart
void main() {
  // 调试模式下启用
  if (kDebugMode) {
    TerminalDebugger.enableDebugLogs = true;
  }
  runApp(MyApp());
}
```

查看控制台输出以诊断问题。

## 构建和运行

```bash
# 重新生成 bridge 代码（如果需要）
flutter_rust_bridge_codegen generate

# 运行应用
flutter run -d linux  # 或 windows/macos
```

## 预期结果

修复后应该能：
1. ✅ 在 Claude Code 长输出时正常滚动
2. ✅ 滚动条可见且响应正确
3. ✅ 可以滚动查看全部历史记录
4. ✅ 下划线只出现在有格式化的地方

## 如果问题仍然存在

1. **启用调试日志**并收集输出
2. **检查是否是 alternate buffer 问题**：
   ```dart
   // 在 terminal_view.dart 的 _handleTerminalChanged 中添加
   debugPrint('Alt buffer: ${terminal.isUsingAltBuffer}');
   ```
3. **尝试禁用 InfiniteScrollView**：
   ```dart
   // scroll_handler.dart:116
   if (false) {  // 完全禁用
     return InfiniteScrollView(...);
   }
   ```
4. **检查 xterm.dart 版本**：可能需要更新 vendored xterm

## 相关文件

- `lib/features/terminal/terminal_view.dart` - 主终端视图
- `third_party/xterm/lib/src/ui/scroll_handler.dart` - 滚动处理
- `third_party/xterm/lib/src/ui/infinite_scroll_view.dart` - 无限滚动实现
- `third_party/xterm/lib/src/ui/render.dart` - 终端渲染
- `lib/core/models/theme_settings.dart` - 主题配置（包括 scrollbackLines）

## 附加信息

- xterm.dart 的 alternate buffer 用于 vim/less/top 等全屏应用
- Claude Code 不使用 alternate buffer，应该使用正常滚动
- `InfiniteScrollView` 只应该在 alternate buffer 模式激活
- 修复确保了这种隔离

## 后续优化建议

1. 考虑添加动态 scrollbackLines 配置（UI 设置）
2. 添加性能监控，确保 50000 行不会影响性能
3. 考虑实现滚动缓冲区的自动清理（保留最近 N 行）
4. 优化下划线渲染性能（如果成为瓶颈）
