#!/bin/bash
# 测试 DeepSSH 滚动修复

set -e

echo "🔍 验证修复文件..."

# 检查关键修复是否存在
if grep -q "!widget.terminal.isUsingAltBuffer" third_party/xterm/lib/src/ui/scroll_handler.dart; then
    echo "✅ scroll_handler.dart 修复已应用"
else
    echo "❌ scroll_handler.dart 修复未应用"
    exit 1
fi

if grep -q "scrollbackLines: 50000" lib/core/models/theme_settings.dart; then
    echo "✅ scrollbackLines 已增加到 50000"
else
    echo "❌ scrollbackLines 未更新"
    exit 1
fi

if [ -f "lib/features/terminal/terminal_debugger.dart" ]; then
    echo "✅ 调试工具已添加"
else
    echo "❌ 调试工具未添加"
    exit 1
fi

echo ""
echo "📦 获取依赖..."
flutter pub get

echo ""
echo "🔨 运行代码分析..."
flutter analyze --no-fatal-infos lib/features/terminal/ lib/core/models/theme_settings.dart || true

echo ""
echo "✨ 所有修复已成功应用！"
echo ""
echo "📝 下一步："
echo "   1. 运行应用：flutter run -d linux"
echo "   2. 打开一个本地终端"
echo "   3. 生成长输出：yes 'Test line' | head -20000"
echo "   4. 验证可以滚动"
echo ""
echo "🐛 调试模式（可选）："
echo "   在 lib/main.dart 添加："
echo "   if (kDebugMode) { TerminalDebugger.enableDebugLogs = true; }"
echo ""
echo "📚 详细文档：docs/CLAUDE_CODE_FIX.md"
