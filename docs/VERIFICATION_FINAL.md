# 🧪 验证 Alternate Buffer Scrollback 修复

## ✅ 已完成的修复

移除了 alternate buffer 进入/退出时的 `clearAltBuffer()` 调用，使得 alternate buffer 也能保留 scrollback 历史。

## 🎯 预期效果

### 修复前（诊断结果）
```
Claude Code:
  Using Alt Buffer: YES
  Scrollback: 0          ← 问题
  Lines in buffer: 51
  Max: 0.00
  Can Scroll: NO ✗
```

### 修复后（预期）
```
Claude Code:
  Using Alt Buffer: YES
  Scrollback: >0         ← 修复了！
  Lines in buffer: 1000+
  Max: >0
  Can Scroll: YES ✓
```

## 🚀 测试步骤

### 1. 推送并重新构建

```bash
# 推送代码
git push origin fix-claude-code-scrolling

# 触发 GitHub Actions 构建
# 访问 https://github.com/hxlh/deepssh/actions
# Run workflow → 选择 fix-claude-code-scrolling 分支
```

### 2. 测试 Claude Code（主要场景）

在新构建的 DeepSSH 中：

```bash
# 启动 Claude Code
claude

# 生成长输出
> 请详细解释 Rust 的所有权系统，包括借用、生命周期、
  move 语义、智能指针、trait bounds、生命周期省略规则...

# 等待输出完成（应该输出很多内容）
```

**测试项**：
1. ✅ **向上滚动** - 用鼠标滚轮或滚动条
   - 应该能看到之前的输出
   - 不应该被"卡"在底部
   
2. ✅ **按 Ctrl+Shift+D** - 查看诊断
   ```
   预期看到：
   Using Alt Buffer: YES
   Scrollback: >0        ← 应该大于 0
   Lines in buffer: >100 ← 应该远大于屏幕大小
   Can Scroll: YES ✓
   ```

3. ✅ **选择文本** - 用鼠标选择
   - 上半屏的文本应该能正常选中
   - 不应该错位

### 3. 测试 vim（确保不破坏）

```bash
# 在 DeepSSH 中打开 vim
vim test.txt

# 输入一些内容
i
Hello World
<ESC>

# 尝试向上滚动（不应该滚动到 vim 之外）
# vim 应该正常工作，不受影响
```

**预期**：vim 的行为完全正常，像以前一样。

### 4. 测试普通命令（确保不破坏）

```bash
# 生成长输出
cat /etc/services  # Linux
seq 1 1000         # 任意平台

# 向上滚动
# 按 Ctrl+Shift+D
```

**预期**：
```
Using Alt Buffer: NO   ← 不在 alt buffer
Scrollback: >0
Can Scroll: YES ✓
```

### 5. 测试 less（确保不破坏）

```bash
# 用 less 查看文件
less /etc/services

# 在 less 中向上/向下滚动（j/k 键）
# 应该正常工作

# 退出 less（q 键）
# 屏幕应该恢复到之前的内容
```

**预期**：less 完全正常工作。

## 📊 测试矩阵

| 应用 | Alt Buffer | 预期 Scrollback | 预期滚动 | 状态 |
|------|-----------|---------------|---------|------|
| Claude Code | YES | >0 | ✓ 可以 | **修复目标** |
| opencode | YES | >0 | ✓ 可以 | **修复目标** |
| vim | YES | 不重要 | ✓ vim内部控制 | 不受影响 |
| less | YES | 不重要 | ✓ less内部控制 | 不受影响 |
| bash | NO | >0 | ✓ 可以 | 不受影响 |

## 🎯 成功标准

修复成功的标志：

1. ✅ **Claude Code 可以滚动**
   - 鼠标滚轮向上可以看到历史
   - 滚动条可见并可用
   - 诊断显示 `Scrollback: >0` 和 `Can Scroll: YES`

2. ✅ **vim/less 仍然正常**
   - 功能完全正常
   - 屏幕绘制正确
   - 退出后恢复屏幕

3. ✅ **普通 shell 不受影响**
   - 滚动正常
   - scrollback 正常

4. ✅ **选择不再错位**
   - 鼠标点击位置和选中位置匹配
   - 上半屏可以正常选中

## 🐛 如果仍有问题

如果修复后仍然无法滚动：

1. **确认版本**
   - 按 Ctrl+Shift+D
   - 检查是否显示增强的诊断信息
   - 确认是新构建的版本

2. **收集诊断**
   - 在 Claude Code 中按 Ctrl+Shift+D
   - 复制完整输出
   - 提供给我分析

3. **检查构建日志**
   - 确认 GitHub Actions 构建成功
   - 确认是从正确的分支构建
   - 确认没有编译错误

## 📝 反馈格式

测试完成后，请提供：

```
✅ Claude Code 滚动测试：
   - 可以向上滚动：[ ] 是 [ ] 否
   - Ctrl+Shift+D Scrollback 值：___
   - 选择是否错位：[ ] 是 [ ] 否

✅ vim 测试：
   - vim 正常工作：[ ] 是 [ ] 否
   - 退出后屏幕恢复：[ ] 是 [ ] 否

✅ 普通命令测试：
   - 滚动正常：[ ] 是 [ ] 否

整体评价：
[ ] 完全修复，所有功能正常
[ ] 部分修复，仍有小问题：_______
[ ] 未修复，问题仍然存在
```

## 🎉 预期结果

如果一切正常，你应该能够：
- ✅ 在 Claude Code 中自由滚动查看历史输出
- ✅ 正常使用 vim/less 等 TUI 应用
- ✅ 选择文本时位置正确，不错位
- ✅ 所有平台（Windows/macOS/Linux）行为一致

---

**这是真正的修复！** 基于准确的根因诊断，移除了不必要的 buffer 清空操作。
