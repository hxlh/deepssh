import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

enum AddConnectionAction { localTerminal, ssh, tunnel }

/// Stable key for a menu entry, so callers can target one action without
/// matching on label text (the same words appear in the page eyebrows).
Key addConnectionMenuKey(AddConnectionAction action) =>
    ValueKey('add-connection-${action.name}');

const Map<AddConnectionAction, ({String label, IconData icon, String hint})>
    addConnectionMenuItems = {
  AddConnectionAction.localTerminal: (
    label: '本地终端',
    icon: Icons.terminal,
    hint: '在当前机器上开一个 shell',
  ),
  AddConnectionAction.ssh: (
    label: 'SSH',
    icon: Icons.dns_outlined,
    hint: '连接一台远程主机',
  ),
  AddConnectionAction.tunnel: (
    label: '隧道连接',
    icon: Icons.swap_horiz,
    hint: '配置端口转发',
  ),
};

/// Trigger + menu for the two "新增连接" entry points (topbar and Explorer
/// header). Both share this widget so the menu can never drift apart.
class AddConnectionButton extends StatelessWidget {
  const AddConnectionButton({
    super.key,
    required this.onSelected,
    this.compact = false,
  });

  final ValueChanged<AddConnectionAction> onSelected;

  /// Drops the label and keeps the icon — used inside the narrow icon rail.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AddConnectionAction>(
      tooltip: '新增连接',
      color: DeckTokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      position: PopupMenuPosition.under,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: DeckTokens.fg),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final entry in addConnectionMenuItems.entries)
          PopupMenuItem<AddConnectionAction>(
            key: addConnectionMenuKey(entry.key),
            value: entry.key,
            height: 44,
            child: Row(
              children: [
                Icon(entry.value.icon, size: 15, color: DeckTokens.muted),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.value.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: DeckTokens.fg,
                      ),
                    ),
                    Text(
                      entry.value.hint,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontFamilyFallback: DeckTokens.fontMono,
                        fontSize: 10,
                        color: DeckTokens.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
      child: _AddConnectionTrigger(compact: compact),
    );
  }
}

class _AddConnectionTrigger extends StatefulWidget {
  const _AddConnectionTrigger({required this.compact});

  final bool compact;

  @override
  State<_AddConnectionTrigger> createState() => _AddConnectionTriggerState();
}

class _AddConnectionTriggerState extends State<_AddConnectionTrigger> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 7 : 9,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: _hovered ? DeckTokens.fgSoft : DeckTokens.bg,
          border: Border.all(color: _hovered ? DeckTokens.fg : DeckTokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 13, color: DeckTokens.fg),
            if (!widget.compact) ...[
              const SizedBox(width: 6),
              const Text(
                '新增连接',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DeckTokens.fg,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
