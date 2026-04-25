import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../workbench/widgets/empty_state.dart';
import '../../workbench/widgets/tab_strip.dart';
import '../ssh/ssh_bridge.dart';
import 'terminal_state.dart';
import 'terminal_view.dart';

class TerminalTabShell extends StatelessWidget {
  const TerminalTabShell({
    super.key,
    required this.state,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.sshBridge,
  });

  final TerminalState state;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<String> onCloseTab;
  final SshBridgeClient sshBridge;

  @override
  Widget build(BuildContext context) {
    final activeTab = state.activeTab;
    if (activeTab == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(color: AppColors.panel),
        child: EmptyState(),
      );
    }

    return Column(
      children: [
        TabStrip(
          tabs: state.tabs,
          activeTabId: state.activeTabId,
          onSelect: onSelectTab,
          onClose: onCloseTab,
        ),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.panel),
            child: TerminalView(
              key: ValueKey(activeTab.id),
              tab: activeTab,
              sshBridge: sshBridge,
            ),
          ),
        ),
      ],
    );
  }
}
