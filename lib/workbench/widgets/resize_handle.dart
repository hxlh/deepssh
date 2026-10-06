import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Broadcasts "the Explorer splitter is being dragged" while the user holds it.
///
/// Resizing the Explorer changes the width of everything to its right, and the
/// terminal answers every width change with a full-buffer reflow — with a deep
/// scrollback that costs milliseconds per frame and makes the drag stutter
/// (the dock splitter only changes heights, which skip the reflow entirely).
/// Widgets that are expensive to resize subscribe to this notifier and hold
/// their last laid-out width until the drag ends, then resize once.
class ExplorerResizeHold extends InheritedNotifier<ValueNotifier<bool>> {
  const ExplorerResizeHold({
    super.key,
    required ValueNotifier<bool> hold,
    required super.child,
  }) : super(notifier: hold);

  /// The active hold notifier, or null when no splitter is in the tree.
  static ValueNotifier<bool>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ExplorerResizeHold>()
        ?.notifier;
  }
}

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
    this.onDraggingChanged,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// Fires with true while a pointer drag is in progress, false once it ends
  /// (or is cancelled). Keyboard steps do not toggle it.
  final ValueChanged<bool>? onDraggingChanged;

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
            widget.onDraggingChanged?.call(true);
          },
          onHorizontalDragEnd: (_) {
            setState(() => _dragging = false);
            widget.onDraggingChanged?.call(false);
          },
          onHorizontalDragCancel: () {
            setState(() => _dragging = false);
            widget.onDraggingChanged?.call(false);
          },
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
