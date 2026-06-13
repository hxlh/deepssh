#!/bin/bash
# 快速设置 Git SSH 认证并推送

echo "🔐 配置 Git SSH 认证..."
echo ""

# 检查是否有 SSH 密钥
if [ ! -f ~/.ssh/id_ed25519 ] && [ ! -f ~/.ssh/id_rsa ]; then
    echo "📝 生成 SSH 密钥..."
    ssh-keygen -t ed25519 -C "hxlh@deepssh" -f ~/.ssh/id_ed25519 -N ""
    echo "✅ SSH 密钥已生成"
fi

# 启动 ssh-agent
eval "$(ssh-agent -s)"

# 添加密钥
if [ -f ~/.ssh/id_ed25519 ]; then
    ssh-add ~/.ssh/id_ed25519
    KEY_FILE=~/.ssh/id_ed25519.pub
elif [ -f ~/.ssh/id_rsa ]; then
    ssh-add ~/.ssh/id_rsa
    KEY_FILE=~/.ssh/id_rsa.pub
fi

echo ""
echo "📋 你的 SSH 公钥："
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat $KEY_FILE
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 请按以下步骤操作："
echo ""
echo "1. 复制上面的 SSH 公钥（包含 'ssh-ed25519' 开头的整行）"
echo "2. 打开浏览器访问："
echo "   https://github.com/settings/keys"
echo "3. 点击 'New SSH key'"
echo "4. Title 填: DeepSSH Development"
echo "5. Key 粘贴上面的公钥"
echo "6. 点击 'Add SSH key'"
echo ""
echo "完成后按回车继续..."
read

# 测试 SSH 连接
echo ""
echo "🔍 测试 GitHub SSH 连接..."
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" && SSH_OK=true || SSH_OK=false

if [ "$SSH_OK" = true ]; then
    echo "✅ SSH 连接成功！"
else
    echo "⚠️  SSH 连接测试失败，但可能是正常的"
    echo "   GitHub SSH 测试会返回认证成功信息"
fi

# 修改远程 URL 为 SSH
echo ""
echo "🔧 修改 Git 远程 URL 为 SSH..."
git remote set-url origin git@github.com:hxlh/deepssh.git
git remote -v

# 推送分支
echo ""
echo "🚀 推送分支到 GitHub..."
git push -u origin fix-claude-code-scrolling

if [ $? -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ 成功推送到 GitHub！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📝 下一步：创建 Pull Request"
    echo ""
    echo "方式 1 - 浏览器："
    echo "  访问: https://github.com/hxlh/deepssh/pull/new/fix-claude-code-scrolling"
    echo ""
    echo "方式 2 - 命令行（需要安装 gh）："
    echo "  gh pr create --title \"fix(terminal): resolve Claude Code scrolling issues\" \\"
    echo "               --body-file QUICK_FIX_GUIDE.md"
    echo ""
else
    echo ""
    echo "❌ 推送失败"
    echo ""
    echo "常见问题："
    echo "1. SSH key 未添加到 GitHub"
    echo "2. 权限不足（需要 repo 的 write 权限）"
    echo "3. 网络连接问题"
    echo ""
    echo "请检查并重试，或使用其他方法（见 PUSH_TO_GITHUB.md）"
fi
