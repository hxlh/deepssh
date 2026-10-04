import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Vertical splitter between the Explorer and the workbench stage.
///
/// Mirrors the prototype's `#sbSplit`: 56–560px, arrow keys move 16px and
/// Home/End jump to the ends. Hovering or focusing tints the 1px rule and shows
/// the same 26px grip the dock splitter uses.
class ResizeHandle extends StatefulWidget {
  const ResizeHandle({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;
  bool _dragging = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _request(double value) {
    widget.onChanged(value.clamp(widget.min, widget.max).toDouble());
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _request(widget.value - 16);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _request(widget.value + 16);
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      _request(widget.min);
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      _request(widget.max);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused || _dragging;
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _focusNode.requestFocus(),
          onHorizontalDragStart: (_) {
            _focusNode.requestFocus();
            setState(() => _dragging = true);
          },
          onHorizontalDragEnd: (_) => setState(() => _dragging = false),
          onHorizontalDragCancel: () => setState(() => _dragging = false),
          onHorizontalDragUpdate: (details) =>
              _request(widget.value + details.delta.dx),
          child: SizedBox(
            width: 7,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 3,
                  child: Container(
                    width: 1,
                    color: active ? AppColors.accent : AppColors.border,
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 3,
                  height: 26,
                  color: active ? AppColors.textPrimary : AppColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
