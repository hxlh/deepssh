import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ResizeHandle extends StatefulWidget {
  const ResizeHandle({super.key, required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          widget.onDrag(details.delta.dx);
        },
        child: Container(
          width: 4,
          color: _hovered ? AppColors.border.withOpacity(0.8) : AppColors.border,
        ),
      ),
    );
  }
}
