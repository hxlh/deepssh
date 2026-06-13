# 🧪 DeepSSH 滚动和选择问题测试指南

## 问题回顾

你报告了两个相关的问题：

1. **无法滚动** - 在 Claude Code、opencode 等应用中，输出很长时无法滚动查看历史
2. **选择错位** - 长时间使用后，鼠标选择的位置与实际选中的文本不匹配，上半屏无法选中

**关键线索**：
- ✅ oh-my-posh 可以滚动（普通 shell）
- ❌ Claude Code 不能滚动（TUI 应用）
- ❌ opencode 不能滚动（TUI 应用）
- 选择问题"越用越严重"

## 🎯 测试计划

### 阶段 1：确认新版本并获取诊断

**目标**：验证你测试的是包含诊断工具的新版本

1. **推送代码到 GitHub**
   ```bash
   # 在你的开发机上
   cd /path/to/deepssh
   git push origin fix-claude-code-scrolling
   ```

2. **触发 GitHub Actions 构建**
   - 访问 https://github.com/hxlh/deepssh/actions
   - 点击 "Package Desktop Builds"
   - Run workflow → 选择 `fix-claude-code-scrolling` 分支
   - 等待构建完成

3. **下载并运行新版本**
   - 下载 Windows 构建产物
   - 解压并运行 DeepSSH
   - 打开一个本地终端

4. **运行诊断命令**
   
   在 DeepSSH 终端中：
   ```bash
   # 生成大量输出
   yes "Test line $(date +%T)" | head -2000
   
   # 按 Ctrl+Shift+D 查看滚动诊断
   # 应该会在终端中显示完整的诊断报告
   ```

   **预期输出**：
   ```
   === Scroll Debug Report ===
   DeepSSH Scroll Diagnostic Report
   ================================
   
   Scroll Position:
     Current: 0.00
     Min: 0.00
     Max: XXXXX.00
     Viewport: XXXX.00
   
   Can Scroll: YES ✓
   
   Terminal Mode:
     Using Alt Buffer: NO
     Lines in buffer: 2000
     ...
   ```

5. **保存诊断结果**
   - 将诊断输出复制到文本文件
   - 或截图
   - 特别注意 `Max:` 和 `Using Alt Buffer:` 的值

### 阶段 2：测试 Claude Code

**目标**：在 Claude Code 中重现问题并获取诊断

1. **启动 Claude Code**
   ```bash
   claude
   ```

2. **生成长输出**
   ```
   > 请详细解释 Rust 的所有权系统，包括借用、生命周期、move 语义...
   ```

3. **尝试滚动**
   - 使用鼠标滚轮向上滚动
   - 观察是否能看到之前的输出
   - 注意是否有滚动条

4. **按 Ctrl+Shift+D**
   - 查看诊断报告
   - **关键指标**：
     - `Max: Infinity` → 说明 InfiniteScrollView 被错误激活
     - `Using Alt Buffer: YES` → Claude Code 在使用 alt buffer
     - `Can Scroll: NO` → 确认无法滚动

5. **测试选择**
   - 尝试用鼠标选择屏幕上半部分的文本
   - 观察选中的是否是你点击的位置
   - 如果错位，记录错位的大致距离（几行）

6. **保存所有信息**
   - Ctrl+Shift+D 的完整输出
   - 截图显示无法滚动
   - 截图显示选择错位

### 阶段 3：对比测试

**目标**：确认问题只在特定场景出现

1. **测试 oh-my-posh（或普通命令）**
   ```bash
   # 生成长输出
   cat /etc/services  # Linux
   type C:\Windows\System32\drivers\etc\services  # Windows
   ```
   
   - 按 Ctrl+Shift+D
   - 尝试滚动
   - 尝试选择文本
   - 记录诊断结果

2. **测试 vim（alternate buffer 应用）**
   ```bash
   vim large_file.txt
   ```
   
   - 在 vim 中按 Ctrl+Shift+D（如果可以）
   - 观察 vim 的滚动是否正常
   - 退出 vim 后再按 Ctrl+Shift+D
   - 比较 alt buffer 激活前后的诊断差异

## 📊 预期结果和分析

### 场景 A：InfiniteScrollView 误激活

**诊断输出**：
```
Max: Infinity
Using Alt Buffer: NO  ← 关键：不在 alt buffer，但 infinite scroll 激活了
Can Scroll: NO
```

**结论**：scroll_handler.dart 的条件判断失效

**修复方向**：
1. 检查 `isAltBuffer` 状态同步
2. 或完全禁用 InfiniteScrollView（测试用）

### 场景 B：Alternate Buffer 本身的问题

**诊断输出**：
```
Max: 0.00  或  Max: (某个有限值)
Using Alt Buffer: YES
Can Scroll: NO
```

**结论**：Claude Code 确实在 alt buffer 模式，但这不应该需要滚动

**疑问**：Claude Code 真的使用 alternate buffer 吗？
- 真实的 TUI 应用（vim, less）使用 alt buffer，退出后屏幕恢复
- Claude Code 是输出流式文本，可能不应该是 alt buffer

**修复方向**：
1. 检查 Claude Code 是否错误地激活了 alt buffer
2. 或者需要特殊处理"伪 TUI"应用

### 场景 C：坐标计算错误

**诊断输出**：
```
Can Scroll: YES
Using Alt Buffer: 可能是 YES 或 NO
但：选择仍然错位
```

**结论**：问题在坐标转换层面，不是滚动本身

**修复方向**：
1. 修复 `getCellOffset` 的坐标计算
2. 检查 `_scrollOffset` 量化逻辑

## 🚨 如果诊断工具不工作

如果按 Ctrl+Shift+D 没有任何输出：

1. **检查构建版本**
   - 确认下载的是 `fix-claude-code-scrolling` 分支的构建
   - 检查 GitHub Actions 日志确认构建成功

2. **检查快捷键冲突**
   - 可能被系统或其他软件占用
   - 尝试修改快捷键（需要重新编译）

3. **查看控制台日志**
   - 如果是 debug 模式，应该能看到应用启动时的版本信息
   - Windows：可能需要从命令行启动查看输出

## 📝 需要提供的信息

测试完成后，请提供：

1. **Ctrl+Shift+D 的完整输出**
   - 在普通命令下
   - 在 Claude Code 下
   - 特别是 `Max:` 和 `Using Alt Buffer:` 的值

2. **截图**
   - 显示无法滚动的情况
   - 显示选择错位的情况
   - 最好标注期望选中的位置和实际选中的位置

3. **GitHub Actions 构建链接**
   - 确认是从正确的分支构建

4. **重现步骤**
   - 如果问题仍然存在，详细的重现步骤
   - 包括具体命令和观察到的现象

## ⏭️ 基于结果的下一步

根据诊断结果，我会：

- **如果是 InfiniteScrollView 误激活** → 修复 scroll_handler.dart 判断逻辑
- **如果是坐标计算错误** → 实施方案 A 或 B（见 ROOT_CAUSE_INVESTIGATION.md）
- **如果 Claude Code 不应该用 alt buffer** → 需要理解 Claude Code 的终端行为
- **如果诊断工具本身有问题** → 修复诊断工具并重新测试

---

**测试目标**：用数据替代猜测，用证据指导修复方向。
