# 🎯 DeepSSH 滚动和选择问题 - 当前状态总结

## 📋 问题描述

你遇到了两个相关问题：

1. **滚动失效**：在 Claude Code、opencode 等应用中，长输出无法滚动查看
2. **选择错位**：长时间使用后，鼠标选择文本时位置不匹配，上半屏无法选中

**关键特征**：
- ✅ 普通 shell（oh-my-posh）滚动正常
- ❌ TUI 应用（Claude Code、opencode）滚动失败
- ❌ 选择问题"越用越严重"（累积性）

## 🔍 调查过程

### 第一轮（失败）：盲目猜测
我最初尝试了：
- 增加 scrollbackLines 到 50000
- 修复 scroll_handler.dart 的 alternate buffer 检测
- 添加基础调试工具

**问题**：这些修改基于**猜测**，没有证据证明是根本原因。你反馈问题仍然存在。

### 第二轮（正确）：系统化调查

我采用了 **superpowers:systematic-debugging** 方法：

1. **收集证据**
   - 查看了之前的相关 commit（c775614 修复 vim 选择问题）
   - 分析了 xterm 的坐标计算、锚点机制、循环缓冲区
   - 识别了 3 个可能的根本原因（见 ROOT_CAUSE_INVESTIGATION.md）

2. **停止猜测**
   - 不再盲目修改代码
   - 转而增强诊断工具
   - 创建明确的测试计划

3. **实施诊断**
   - 增强 Ctrl+Shift+D 诊断输出
   - 添加 alternate buffer 状态检测
   - 添加详细的错误诊断消息

## 📦 当前分支状态

**分支**：`fix-claude-code-scrolling`

**提交历史**：
```
a9d5fc0 docs: add comprehensive testing guide
a507cba debug: enhance scroll diagnostics for alternate buffer detection
0e6bf33 feat(debug): add scroll diagnostics and verification tools
7e194a7 fix(terminal): resolve scrolling issues (初始修复)
```

**关键文件**：
- ✅ 诊断工具：`lib/features/terminal/terminal_scroll_debugger.dart`
- ✅ 调试快捷键：Ctrl+Shift+D（在 `lib/features/terminal/terminal_view.dart`）
- ✅ 根因假设：`ROOT_CAUSE_INVESTIGATION.md`
- ✅ 测试指南：`TESTING_GUIDE.md`
- ✅ 版本标识：`lib/core/version_info.dart`

## 🚀 下一步行动（需要你做）

### 1. 推送代码
```bash
git push origin fix-claude-code-scrolling
```

### 2. 触发 GitHub Actions 构建
- 访问 https://github.com/hxlh/deepssh/actions
- 手动运行 "Package Desktop Builds"
- 选择 `fix-claude-code-scrolling` 分支
- 下载 Windows 构建产物

### 3. 测试并收集诊断
按照 **TESTING_GUIDE.md** 的步骤：

1. 在普通命令下按 Ctrl+Shift+D
2. 在 Claude Code 中按 Ctrl+Shift+D
3. 截图或复制完整的诊断输出
4. 将结果发给我

### 4. 提供诊断结果
我需要看到：
- `Max: ???` 的值（Infinity？有限值？）
- `Using Alt Buffer: ???`（YES？NO？）
- `Can Scroll: ???`（YES？NO？）
- 选择是否仍然错位

## 🎯 三种可能的根本原因

基于诊断结果，问题可能是以下之一：

### 假设 A：InfiniteScrollView 误激活
**症状**：`Max: Infinity` + `Using Alt Buffer: NO`  
**原因**：scroll_handler.dart 判断失效  
**修复**：修正条件判断或禁用 InfiniteScrollView

### 假设 B：Alternate Buffer 坐标计算错误
**症状**：`Using Alt Buffer: YES` + 选择错位  
**原因**：`getCellOffset` 在 alt buffer 下计算错误  
**修复**：修改 render.dart 的坐标转换逻辑

### 假设 C：Claude Code 不应该使用 Alternate Buffer
**症状**：`Using Alt Buffer: YES` 但 Claude Code 不是传统 TUI  
**原因**：误判应用类型  
**修复**：调整 alternate buffer 检测逻辑

## 📊 为什么这次方法更好

| 之前的方法 | 现在的方法 |
|-----------|-----------|
| 猜测 → 修改 → 测试 → 失败 | 诊断 → 证据 → 假设 → 修复 |
| 堆砌多个"可能的修复" | 一次只测试一个假设 |
| 无法知道哪个改动有效 | 每个改动都有明确目标 |
| 问题仍然存在 | 用数据指导方向 |

## 💬 需要反馈

1. **你能推送代码并重新构建吗？**
   - 如果 SSH 推送仍然失败，可以尝试 Personal Access Token
   - 或者直接在 GitHub 网页上合并分支

2. **运行测试后的诊断输出是什么？**
   - 特别是 `Max:` 和 `Using Alt Buffer:` 的值

3. **问题是否仍然存在？**
   - 如果是，提供诊断输出
   - 如果解决了，哪个改动有效？

## 📚 相关文档

- **TESTING_GUIDE.md** - 详细测试步骤（⭐ 从这里开始）
- **ROOT_CAUSE_INVESTIGATION.md** - 根因假设和修复方案
- **VERIFICATION_GUIDE.md** - 如何验证修复
- **CURRENT_STATUS.md** - 之前的状态总结

---

**核心原则**：用证据替代猜测，用诊断指导修复。

下一步完全取决于你的测试结果！
