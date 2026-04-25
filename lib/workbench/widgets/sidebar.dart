import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'add_connection_button.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.child,
    required this.onAddConnectionSelected,
  });

  final Widget child;
  final ValueChanged<AddConnectionAction> onAddConnectionSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'EXPLORER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                AddConnectionButton(onSelected: onAddConnectionSelected),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
