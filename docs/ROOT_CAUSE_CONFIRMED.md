# DeepSSH Claude Code 滚动问题 - 根本原因确认

## 🎯 诊断结果

### Claude Code
```
Using Alt Buffer: YES
Max: 0.00
Can Scroll: NO
Scrollback: 0
```

### 普通命令
```
Using Alt Buffer: NO  
Max: 40137.00
Can Scroll: YES ✓
Scrollback: 2361
```

## 💡 根本原因

**Claude Code 发送了 alternate buffer 切换序列**（`ESC[?1049h`），导致终端进入 alternate buffer 模式。

### 什么是 Alternate Buffer？

Alternate buffer 是终端的一个特殊模式，用于**全屏 TUI 应用**：
- vim、less、top、htop 等
- 进入时：保存当前屏幕，切换到空白 buffer
- 退出时：恢复原屏幕，TUI 内容消失
- **没有 scrollback**：因为是临时的全屏界面

### Claude Code 的问题

Claude Code 是一个**流式文本输出工具**，类似于普通 shell，应该：
- ✅ 有 scrollback 历史
- ✅ 可以滚动查看之前的输出
- ✅ 退出后内容保留

但它发送了 alternate buffer 序列，导致：
- ❌ 没有 scrollback（`Scrollback: 0`）
- ❌ 无法滚动（`Max: 0.00`）
- ❌ 像 vim 一样工作，但这不是想要的

## 🔧 解决方案

### 选项 A：忽略 Alternate Buffer 序列（推荐）

在 xterm 输入处理中，拦截并忽略 `ESC[?1049h`（进入 alt buffer）和 `ESC[?1049l`（退出 alt buffer）序列。

**优点**：
- Claude Code 会像普通 shell 一样工作
- 有完整的 scrollback
- 可以滚动查看历史

**缺点**：
- 可能影响真正需要 alt buffer 的应用（但 Claude Code 不需要）

### 选项 B：添加"伪 Alt Buffer"模式

创建一个特殊模式：
- 接受 alt buffer 切换序列
- 但保留 scrollback 功能
- 允许滚动

**优点**：
- 兼容性好
- 不会破坏其他应用

**缺点**：
- 实现复杂
- 可能有副作用

### 选项 C：添加应用特定配置

检测 Claude Code（通过进程名或输出特征），对其特殊处理。

**优点**：
- 精确针对 Claude Code
- 不影响其他应用

**缺点**：
- 需要维护应用列表
- opencode 也有同样问题，需要都加进去

## 🎯 推荐方案：选项 A

**实现**：在 xterm 的输入处理中忽略 alternate buffer 序列。

**位置**：`third_party/xterm/lib/src/core/input/handler.dart`

**影响**：
- ✅ Claude Code 可以正常滚动
- ✅ opencode 也会正常工作
- ⚠️ vim/less 仍然正常（它们有其他方式检测是否在 alt buffer）

## 📋 后续步骤

1. 实现修复（忽略 alternate buffer 序列）
2. 测试 Claude Code - 应该可以滚动
3. 测试 vim/less - 应该仍然正常工作
4. 如果 vim/less 有问题，切换到选项 B 或 C

## 🤔 为什么 Claude Code 使用 Alternate Buffer？

可能的原因：
1. Claude Code 使用了某个 TUI 库，该库默认启用 alt buffer
2. 为了实现某些视觉效果（加载动画、进度条）
3. 开发者误用了终端功能

这可能是 Claude Code 本身的 bug，但我们可以在 DeepSSH 中 workaround。

## 📊 对比

| 应用 | Alt Buffer | Scrollback | 期望行为 |
|------|-----------|-----------|---------|
| vim | YES | 0 | ✅ 正确 |
| less | YES | 0 | ✅ 正确 |
| bash | NO | >0 | ✅ 正确 |
| Claude Code | YES | 0 | ❌ 错误（应该像 bash） |
| opencode | YES | 0 | ❌ 错误（应该像 bash） |

## 🎉 调查成功

通过系统化调试和诊断工具，我们准确定位了问题：
- ✅ 不是 InfiniteScrollView 的问题
- ✅ 不是 scrollbackLines 太小
- ✅ 不是坐标计算错误
- ✅ 是 Claude Code 错误使用了 alternate buffer

现在可以实施精确的修复！
