import 'package:flutter/material.dart';

import '../../core/models/host_item.dart';
import '../../core/models/terminal_item.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class HostTreeNode extends StatelessWidget {
  const HostTreeNode({
    super.key,
    required this.host,
    required this.expanded,
    required this.selectedTerminalId,
    required this.onToggle,
    required this.onTerminalTap,
  });

  final HostItem host;
  final bool expanded;
  final String? selectedTerminalId;
  final VoidCallback onToggle;
  final ValueChanged<TerminalItem> onTerminalTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              height: AppSpacing.itemHeight,
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  Icon(Icons.computer, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(host.name),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          ...host.terminals.map(
            (terminal) => _TerminalRow(
              terminal: terminal,
              selected: terminal.id == selectedTerminalId,
              onTap: () => onTerminalTap(terminal),
            ),
          ),
      ],
    );
  }
}

class _TerminalRow extends StatelessWidget {
  const _TerminalRow({
    required this.terminal,
    required this.selected,
    required this.onTap,
  });

  final TerminalItem terminal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: AppSpacing.itemHeight,
        margin: const EdgeInsets.fromLTRB(24, 2, 8, 2),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.selection : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Row(
          children: [
            Icon(Icons.terminal, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(terminal.title, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
