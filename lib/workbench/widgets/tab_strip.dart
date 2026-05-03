import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/terminal/terminal_state.dart';

class TabStrip extends StatefulWidget {
  const TabStrip({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onSelect,
    required this.onClose,
    required this.onReorder,
  });

  final List<OpenTerminalTab> tabs;
  final String? activeTabId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  State<TabStrip> createState() => _TabStripState();
}

class _TabStripState extends State<TabStrip> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.kind != PointerDeviceKind.mouse ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        )) {
      return;
    }

    final dy = event.scrollDelta.dy;
    if (dy == 0 || !_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final target = (position.pixels + dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) {
      position.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: Container(
        height: AppSpacing.tabHeight,
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: ReorderableListView.builder(
          scrollController: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: widget.tabs.length,
          onReorder: widget.onReorder,
          buildDefaultDragHandles: false,
          itemBuilder: (context, index) {
            final tab = widget.tabs[index];
            final active = tab.id == widget.activeTabId;
            return ReorderableDragStartListener(
              key: ValueKey(tab.id),
              index: index,
              child: _TabItem(
                tab: tab,
                active: active,
                onSelect: () => widget.onSelect(tab.id),
                onClose: () => widget.onClose(tab.id),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.tab,
    required this.active,
    required this.onSelect,
    required this.onClose,
  });

  final OpenTerminalTab tab;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool tabHovered = false;
  bool closeHovered = false;

  static const Color _hoverInactive = Color(0xFF222426);

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final Color background = active
        ? AppColors.tabActive
        : (tabHovered ? _hoverInactive : AppColors.tabInactive);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => tabHovered = true),
      onExit: (_) => setState(() => tabHovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: background,
            border: Border(
              top: BorderSide(
                color: active ? AppColors.accent : Colors.transparent,
                width: 2,
              ),
              right: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.tab.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Close ${widget.tab.label}',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => closeHovered = true),
                  onExit: (_) => setState(() => closeHovered = false),
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: closeHovered
                            ? AppColors.border
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: closeHovered
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
