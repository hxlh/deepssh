# 推送分支到 GitHub

你的代码已经在本地分支 `fix-claude-code-scrolling` 提交完成！

## 当前状态
- ✅ 分支创建: `fix-claude-code-scrolling`
- ✅ 代码提交: commit `7e194a7`
- ✅ 11 个文件，1269 行变更
- ⏳ 等待推送到 GitHub

## 推送方法

### 方法 1: 使用 GitHub CLI (推荐)

如果已安装 `gh`：
```bash
# 认证（如果尚未认证）
gh auth login

# 推送并创建 PR
gh pr create --title "fix(terminal): resolve Claude Code scrolling issues" \
             --body "Fixes scrolling when rendering long Claude Code outputs" \
             --base master \
             --head fix-claude-code-scrolling
```

### 方法 2: 配置 SSH

```bash
# 1. 生成 SSH 密钥（如果没有）
ssh-keygen -t ed25519 -C "your_email@example.com"

# 2. 添加到 ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# 3. 复制公钥并添加到 GitHub
cat ~/.ssh/id_ed25519.pub
# 访问 https://github.com/settings/keys 添加 SSH key

# 4. 修改远程 URL 为 SSH
git remote set-url origin git@github.com:hxlh/deepssh.git

# 5. 推送
git push origin fix-claude-code-scrolling
```

### 方法 3: 使用个人访问令牌 (PAT)

```bash
# 1. 生成 PAT
# 访问 https://github.com/settings/tokens
# 创建新的 Personal Access Token (classic)
# 勾选 repo 权限

# 2. 推送时输入凭据
git push origin fix-claude-code-scrolling
# Username: 你的 GitHub 用户名
# Password: 粘贴 PAT (不是实际密码)

# 3. 保存凭据（可选）
git config --global credential.helper store
```

### 方法 4: 在 GitHub Web 界面操作

```bash
# 1. 生成补丁文件
git format-patch master..fix-claude-code-scrolling -o /tmp/patches

# 2. 手动在 GitHub 上创建分支并应用补丁
```

## 推荐：使用 GitHub CLI

最简单的方法是使用 `gh` CLI：

```bash
# 安装 gh (如果没有)
# Ubuntu/Debian
sudo apt install gh

# Arch Linux
sudo pacman -S github-cli

# 认证
gh auth login

# 推送并创建 PR（一条命令完成）
gh pr create --title "fix(terminal): resolve Claude Code scrolling issues" \
             --body-file QUICK_FIX_GUIDE.md \
             --base master \
             --head fix-claude-code-scrolling
```

## 手动推送命令

当你配置好认证后，运行：

```bash
# 推送分支
git push -u origin fix-claude-code-scrolling

# 查看推送后的 URL
git remote show origin
```

## PR 描述建议

创建 Pull Request 时可以使用以下内容：

**标题**:
```
fix(terminal): resolve Claude Code scrolling issues
```

**描述**:
```markdown
## 问题
在 DeepSSH 中运行 Claude Code 时，长输出无法滚动查看。

## 原因
`InfiniteScrollView` 被错误地在普通模式激活，导致 `maxScrollExtent = ∞`。

## 修复
1. 修复 scroll_handler.dart 的 alternate buffer 检测
2. 增加 scrollbackLines 到 50000
3. 添加调试工具

## 测试
- ✅ Claude Code 长输出可以正常滚动
- ✅ vim/less 不受影响
- ✅ 正常终端操作无变化

详细文档见 QUICK_FIX_GUIDE.md
```

## 下一步

1. 选择上述一种方法配置 Git 认证
2. 推送分支到 GitHub
3. 创建 Pull Request
4. 等待 CI 检查通过
5. 合并到 master

## 需要帮助？

如果遇到问题，告诉我：
- 你的 Git 认证方式（SSH/HTTPS）
- 是否安装了 `gh` CLI
- 推送时的具体错误信息
