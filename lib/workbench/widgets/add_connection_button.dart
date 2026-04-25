import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AddConnectionAction { localTerminal, ssh }

class AddConnectionButton extends StatelessWidget {
  const AddConnectionButton({super.key, required this.onSelected});

  final ValueChanged<AddConnectionAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AddConnectionAction>(
      tooltip: '新增连接',
      color: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: AddConnectionAction.localTerminal,
          child: Text('本地终端'),
        ),
        PopupMenuItem(value: AddConnectionAction.ssh, child: Text('SSH')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.tabInactive,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: AppColors.textPrimary),
            SizedBox(width: 6),
            Text(
              '新增连接',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
