import 'package:flutter/material.dart';

import '../../core/models/local_terminal_item.dart';
import '../../core/models/terminal_item.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'host_tree_node.dart';
import 'host_tree_state.dart';

class HostTree extends StatelessWidget {
  const HostTree({
    super.key,
    required this.state,
    required this.selectedTerminalId,
    required this.onToggleHost,
    required this.onTerminalTap,
    required this.localTerminals,
    required this.localExpanded,
    required this.onToggleLocal,
    required this.onLocalTerminalTap,
  });

  final HostTreeState state;
  final String? selectedTerminalId;
  final ValueChanged<String> onToggleHost;
  final ValueChanged<TerminalItem> onTerminalTap;
  final List<LocalTerminalItem> localTerminals;
  final bool localExpanded;
  final VoidCallback onToggleLocal;
  final ValueChanged<LocalTerminalItem> onLocalTerminalTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: [
        ...state.hosts.map((host) {
          return HostTreeNode(
            host: host,
            expanded: state.isExpanded(host.id),
            selectedTerminalId: selectedTerminalId,
            onToggle: () => onToggleHost(host.id),
            onTerminalTap: onTerminalTap,
          );
        }),
        if (localTerminals.isNotEmpty) ...[
          InkWell(
            onTap: onToggleLocal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                height: AppSpacing.itemHeight,
                child: Row(
                  children: [
                    Icon(
                      localExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const Icon(Icons.laptop, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    const Text('Local'),
                  ],
                ),
              ),
            ),
          ),
          if (localExpanded)
            ...localTerminals.map(
              (terminal) => InkWell(
                onTap: () => onLocalTerminalTap(terminal),
                child: Container(
                  height: AppSpacing.itemHeight,
                  margin: const EdgeInsets.fromLTRB(24, 2, 8, 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: selectedTerminalId == terminal.id
                        ? AppColors.selection
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radius),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          terminal.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
