# DeepSSH 选择错位问题 - 根因调查

## 问题症状（已确认）

1. ✅ **只在 alternate buffer 应用出现**（Claude Code、opencode）
2. ✅ **普通应用正常**（oh-my-posh、bash）
3. ✅ **越用越严重**（累积性bug）
4. ✅ **选择错位**（鼠标点击位置与实际选中位置不匹配）
5. ✅ **上半屏无法选中**（长时间使用后）

## 根因假设

### 假设 1：Alternate Buffer 下的坐标计算错误

**证据**：
- `getCellOffset()` (render.dart:340-348) 使用 `_scrollOffset` 计算鼠标→cell 坐标
- `_scrollOffset` 被量化到行高的倍数（line 322-324）
- Alternate buffer 应用使用 `InfiniteScrollView`

**推测**：
在 alternate buffer 模式下：
1. `InfiniteScrollView` 设置 `applyContentDimensions(double.negativeInfinity, double.infinity)`
2. 但 `_scrollOffset` 的计算仍然依赖 `_offset.pixels`
3. 当 pixels 值异常时（infinite scroll 模式），量化计算出错
4. 导致 `getCellOffset` 返回错误的 y 坐标

**测试方法**：
在 alternate buffer 应用中按 Ctrl+Shift+D，检查：
- `_offset.pixels` 的值
- `maxScrollExtent` 是否是 Infinity
- `_scrollOffset` 的计算结果

### 假设 2：InfiniteScrollView 未被正确禁用

**证据**：
- 我之前的修复添加了双重检查（line 119, scroll_handler.dart）
- 但可能条件判断仍然不完整

**推测**：
- `isAltBuffer` 状态变量可能延迟更新
- 或者 `terminal.isUsingAltBuffer` 在某些情况下不准确
- 导致 InfiniteScrollView 在不该激活时激活

**测试方法**：
在 scroll_handler.dart 的 build() 方法中添加日志：
```dart
debugPrint('[ScrollHandler] isAltBuffer=$isAltBuffer, terminal.isUsingAltBuffer=${widget.terminal.isUsingAltBuffer}');
if (!isAltBuffer || !widget.terminal.isUsingAltBuffer) {
  debugPrint('[ScrollHandler] Using normal scroll');
  return widget.child;
}
debugPrint('[ScrollHandler] Using InfiniteScrollView');
```

### 假设 3：选择锚点在 Alternate Buffer 下失效

**证据**：
- Commit c775614 修复了类似问题（vim 中滚动后选择失效）
- 但修复只针对 scrollUp/scrollDown/deleteLines
- Alternate buffer 可能有其他操作导致锚点失效

**推测**：
- Alternate buffer 的某些操作（清屏、重绘）导致锚点 detach
- 或者锚点的 y 坐标计算（通过 `_owner!.index`）在 alt buffer 下不正确

**测试方法**：
创建测试用例，在 alternate buffer 下：
1. 进入 vim
2. 创建选择
3. 滚动
4. 检查 anchor.attached 和 anchor.y

## 修复方案（按优先级）

### 方案 A：禁用 Alternate Buffer 下的量化滚动

**目标**：在 alternate buffer 模式下，`_scrollOffset` 直接返回 `_offset.pixels`，不量化

**实现**：
```dart
// render.dart
double get _scrollOffset {
  // 在 alternate buffer 下不量化，避免坐标计算错误
  if (_terminal.isUsingAltBuffer) {
    return _offset.pixels;
  }
  return _offset.pixels ~/ _painter.cellSize.height * _painter.cellSize.height;
}
```

**风险**：可能影响 alternate buffer 的渲染对齐

### 方案 B：修复 getCellOffset 在 Alternate Buffer 下的计算

**目标**：alternate buffer 下使用不同的坐标计算逻辑

**实现**：
```dart
// render.dart
CellOffset getCellOffset(Offset offset) {
  final x = offset.dx - _padding.left;
  final y = offset.dy - _padding.top + _scrollOffset;
  
  // 在 alternate buffer 下，直接基于 viewport 坐标
  if (_terminal.isUsingAltBuffer) {
    final row = (offset.dy - _padding.top) ~/ _painter.cellSize.height;
    final col = x ~/ _painter.cellSize.width;
    return CellOffset(
      col.clamp(0, _terminal.viewWidth - 1),
      row.clamp(0, _terminal.viewHeight - 1),  // 只在可见区域
    );
  }
  
  // 原有逻辑（普通buffer）
  final row = y ~/ _painter.cellSize.height;
  final col = x ~/ _painter.cellSize.width;
  return CellOffset(
    col.clamp(0, _terminal.viewWidth - 1),
    row.clamp(0, _terminal.buffer.lines.length - 1),
  );
}
```

### 方案 C：完全禁用 InfiniteScrollView

**目标**：强制所有模式使用正常滚动

**实现**：
```dart
// scroll_handler.dart
@override
Widget build(BuildContext context) {
  // 完全禁用 InfiniteScrollView，仅用于测试
  return widget.child;
}
```

**用途**：测试是否是 InfiniteScrollView 导致的问题

## 下一步行动

1. **重新构建包含调试工具的版本**
   - 确保 Ctrl+Shift+D 调试快捷键有效
   - 确保版本标识正确

2. **在 Windows 上测试**
   - 运行 Claude Code
   - 按 Ctrl+Shift+D 获取滚动诊断
   - 尝试选择文本，观察错位情况

3. **根据诊断结果选择修复方案**
   - 如果 `maxScrollExtent = Infinity` → 方案 A 或 B
   - 如果锚点 detached → 需要修复锚点逻辑
   - 如果都不是 → 需要更深入调查

## 关键代码位置

- `getCellOffset`: third_party/xterm/lib/src/ui/render.dart:340
- `_scrollOffset`: third_party/xterm/lib/src/ui/render.dart:322
- `scroll_handler.dart`: third_party/xterm/lib/src/ui/scroll_handler.dart:114
- `InfiniteScrollView`: third_party/xterm/lib/src/ui/infinite_scroll_view.dart:113
