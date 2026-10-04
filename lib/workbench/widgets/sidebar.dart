import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/deck_widgets.dart';
import 'add_connection_button.dart';

/// Explorer column: header row plus the tree.
///
/// The header's "新增连接" is the icon-only variant — the topbar carries the
/// labelled one. Both open the same menu; keeping the Explorer trigger compact
/// avoids two identical labels sitting in the same viewport.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.child,
    required this.onAddConnectionSelected,
    required this.width,
    this.compact = false,
  });

  /// Width at or below which the column becomes an icon rail.
  static const double compactBreakpoint = 96;

  final Widget child;
  final ValueChanged<AddConnectionAction> onAddConnectionSelected;
  final double width;

  /// True once the column is narrow enough to be an icon rail.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.textPrimary)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 40,
            padding: EdgeInsets.fromLTRB(12, 0, 8, 0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                // Clipped rather than removed so the label stays reachable to
                // screen readers when the rail collapses.
                if (!compact)
                  const Expanded(child: DeckLabel('Explorer', size: 10.5)),
                AddConnectionButton(
                  onSelected: onAddConnectionSelected,
                  compact: true,
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
