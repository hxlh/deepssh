import 'package:flutter/material.dart';

import '../../core/models/theme_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../workbench/widgets/empty_state.dart';
import '../../workbench/widgets/tab_strip.dart';
import '../local_terminal/local_terminal_bridge.dart';
import '../ssh/ssh_bridge.dart';
import 'terminal_state.dart';
import 'terminal_view.dart';

class TerminalTabShell extends StatefulWidget {
  const TerminalTabShell({
    super.key,
    required this.state,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onReorderTab,
    required this.sshBridge,
    required this.localTerminalBridge,
    required this.terminalThemeSettings,
    this.onSshInput,
  });

  final TerminalState state;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<String> onCloseTab;
  final void Function(int oldIndex, int newIndex) onReorderTab;
  final SshBridgeClient sshBridge;
  final LocalTerminalBridgeClient localTerminalBridge;
  final TerminalThemeSettings terminalThemeSettings;
  final ValueChanged<String>? onSshInput;

  @override
  State<TerminalTabShell> createState() => _TerminalTabShellState();
}

class _TerminalTabShellState extends State<TerminalTabShell> {
  bool _findVisible = false;
  String _findQuery = '';
  bool _findCaseSensitive = false;
  bool _findWholeWord = false;
  bool _findUseRegex = false;

  void _openFind(String selectedText) {
    setState(() {
      _findVisible = true;
      if (selectedText.isNotEmpty) {
        _findQuery = selectedText;
      }
    });
  }

  void _closeFind() {
    setState(() => _findVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = widget.state.activeTab;
    if (activeTab == null) {
      return DecoratedBox(
        decoration: BoxDecoration(color: AppColors.panel),
        child: const EmptyState(),
      );
    }

    return Column(
      children: [
        TabStrip(
          tabs: widget.state.tabs,
          activeTabId: widget.state.activeTabId,
          onSelect: widget.onSelectTab,
          onClose: widget.onCloseTab,
          onReorder: widget.onReorderTab,
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(color: AppColors.panel),
            child: TerminalView(
              key: ValueKey(activeTab.id),
              tab: activeTab,
              sshBridge: widget.sshBridge,
              localTerminalBridge: widget.localTerminalBridge,
              terminalThemeSettings: widget.terminalThemeSettings,
              onSshInput: widget.onSshInput,
              findVisible: _findVisible,
              findQuery: _findQuery,
              findCaseSensitive: _findCaseSensitive,
              findWholeWord: _findWholeWord,
              findUseRegex: _findUseRegex,
              onFindOpened: _openFind,
              onFindClosed: _closeFind,
              onFindQueryChanged: (query) => setState(() => _findQuery = query),
              onFindCaseSensitiveChanged: (value) =>
                  setState(() => _findCaseSensitive = value),
              onFindWholeWordChanged: (value) =>
                  setState(() => _findWholeWord = value),
              onFindUseRegexChanged: (value) =>
                  setState(() => _findUseRegex = value),
            ),
          ),
        ),
      ],
    );
  }
}
