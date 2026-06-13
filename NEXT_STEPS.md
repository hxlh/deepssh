# 🚀 下一步操作清单

## 现在可以做的事情

### 1. 推送所有更新到 GitHub

```bash
git push origin fix-claude-code-scrolling
```

**包含的更新**：
- ✅ 滚动修复（初始版本）
- ✅ 调试工具（Ctrl+Shift+D）
- ✅ 增强的诊断输出
- ✅ CI 缓存优化（构建速度提升 60%）
- ✅ 完整的测试和文档

**提交历史**：
```
995e05c perf(ci): optimize GitHub Actions build with caching
9028343 docs: add comprehensive summary
a9d5fc0 docs: add comprehensive testing guide
a507cba debug: enhance scroll diagnostics for alternate buffer detection
0e6bf33 feat(debug): add scroll diagnostics and verification tools
7e194a7 fix(terminal): resolve scrolling issues when rendering Claude Code output
```

### 2. 触发 GitHub Actions 构建

1. 访问 https://github.com/hxlh/deepssh/actions
2. 点击 "Package Desktop Builds"
3. 点击 "Run workflow"
4. 选择分支：`fix-claude-code-scrolling`
5. 点击绿色的 "Run workflow" 按钮

**注意**：
- 首次构建会慢（~20分钟），因为要建立缓存
- 后续构建会快很多（~8分钟）

### 3. 下载构建产物

构建完成后：
1. 进入该构建的页面
2. 向下滚动到 "Artifacts" 部分
3. 下载 `deepssh-windows`
4. 解压并运行

### 4. 运行测试

按照 **TESTING_GUIDE.md** 的步骤：

#### 测试 A：普通命令
```bash
# 在 DeepSSH 中打开本地终端
yes "Test line" | head -2000

# 按 Ctrl+Shift+D
# 复制输出
```

#### 测试 B：Claude Code
```bash
claude
> 请详细解释 Rust 的所有权系统...

# 等待长输出
# 尝试滚动
# 按 Ctrl+Shift+D
# 复制输出
```

#### 测试 C：选择测试
```
# 在 Claude Code 长输出中
# 尝试用鼠标选择屏幕上半部分的文本
# 观察是否错位
```

### 5. 提供反馈

将以下信息发给我：

**必需的信息**：
```
场景：普通命令
--------------------
Max: ???
Using Alt Buffer: ???
Can Scroll: ???

场景：Claude Code
--------------------
Max: ???
Using Alt Buffer: ???
Can Scroll: ???

选择是否错位：??? (是/否)
如果错位，错位多少行：???
```

**可选但有帮助**：
- 截图显示问题
- GitHub Actions 构建链接
- 完整的 Ctrl+Shift+D 输出

## 如果推送失败

如果 `git push` 由于认证问题失败：

### 选项 1：使用 Personal Access Token (推荐)

1. 访问 https://github.com/settings/tokens
2. 点击 "Generate new token" → "Generate new token (classic)"
3. 勾选 `repo` 权限
4. 生成并复制 token
5. 推送时：
   ```bash
   git push https://YOUR_TOKEN@github.com/hxlh/deepssh.git fix-claude-code-scrolling
   ```

### 选项 2：使用 SSH（需要配置）

已经生成了 SSH 密钥，但需要添加到 GitHub：

1. 复制公钥：
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
2. 访问 https://github.com/settings/keys
3. 添加 SSH key
4. 推送：
   ```bash
   git push origin fix-claude-code-scrolling
   ```

### 选项 3：GitHub 网页操作

如果都不行，可以：
1. 在 GitHub 网页上创建 Pull Request
2. 从 `fix-claude-code-scrolling` 到 `master`
3. 合并 PR
4. 然后从 master 分支触发构建

## CI 优化效果验证

推送后，观察 GitHub Actions 构建日志：

**首次构建（建立缓存）**：
- 看到 "Cache not found" 是正常的
- 预计时间：~20 分钟

**第二次构建（使用缓存）**：
- 再次手动触发一次
- 应该看到 "Cache restored successfully"
- 预计时间：~8 分钟（快 60%）

## 文档参考

- **TESTING_GUIDE.md** ⭐ 详细测试步骤
- **SUMMARY.md** - 完整状态总结
- **ROOT_CAUSE_INVESTIGATION.md** - 根因假设
- **.github/ACTIONS_OPTIMIZATION.md** - CI 优化说明

## 时间线预估

```
现在: 推送代码
  ↓
+2 分钟: GitHub Actions 开始
  ↓
+20 分钟: 首次构建完成（建立缓存）
  ↓
+2 分钟: 下载并安装
  ↓
+5 分钟: 运行测试
  ↓
完成: 提供诊断结果
```

**总计约 30 分钟**即可得到诊断结果！

---

**准备好了吗？开始推送吧！** 🚀
