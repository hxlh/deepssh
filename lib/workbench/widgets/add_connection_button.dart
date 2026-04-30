import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AddConnectionAction { localTerminal, ssh, tunnel }

class AddConnectionButton extends StatefulWidget {
  const AddConnectionButton({super.key, required this.onSelected});

  final ValueChanged<AddConnectionAction> onSelected;

  @override
  State<AddConnectionButton> createState() => _AddConnectionButtonState();
}

class _AddConnectionButtonState extends State<AddConnectionButton> {
  bool hovered = false;

  static const Color _hoverBg = Color(0xFF222426);
  static const Color _hoverBorder = Color(0xFF3A3A3A);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: PopupMenuButton<AddConnectionAction>(
        tooltip: '新增连接',
        color: AppColors.panel,
        surfaceTintColor: Colors.transparent,
        onSelected: widget.onSelected,
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: AddConnectionAction.localTerminal,
            child: Text('本地终端'),
          ),
          PopupMenuItem(value: AddConnectionAction.ssh, child: Text('SSH')),
          PopupMenuItem(value: AddConnectionAction.tunnel, child: Text('隧道连接')),
        ],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hovered ? _hoverBg : AppColors.tabInactive,
            border: Border.all(
              color: hovered ? _hoverBorder : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: AppColors.textPrimary),
              const SizedBox(width: 6),
              Text(
                '新增连接',
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
