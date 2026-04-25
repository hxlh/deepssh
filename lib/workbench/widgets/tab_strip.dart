import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/terminal/terminal_state.dart';

class TabStrip extends StatelessWidget {
  const TabStrip({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onSelect,
    required this.onClose,
  });

  final List<OpenTerminalTab> tabs;
  final String? activeTabId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.tabHeight,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final active = tab.id == activeTabId;
          return GestureDetector(
            onTap: () => onSelect(tab.id),
            child: Container(
              width: 220,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? AppColors.tabActive : AppColors.tabInactive,
                border: Border(
                  top: BorderSide(
                    color: active ? AppColors.accent : Colors.transparent,
                    width: 2,
                  ),
                  right: const BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tab.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Close ${tab.label}',
                    child: GestureDetector(
                      onTap: () => onClose(tab.id),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
