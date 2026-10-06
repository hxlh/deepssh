import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Key of the dashed slot that marks where a dragged row will land.
const Key sessionDropShadeKey = ValueKey('session-drop-shade');

/// Row geometry shared with [HostTree]: the drop slot is inset exactly like a
/// row body so the dashed border sits on the same box the row will occupy.
class SessionRowMetrics {
  const SessionRowMetrics({
    required this.rowHeight,
    required this.rowGap,
    required this.rowLeft,
    required this.rowRight,
  });

  final double rowHeight;
  final double rowGap;
  final double rowLeft;
  final double rowRight;

  /// The vertical pitch of one row including its outer margins.
  double get slotHeight => rowHeight + rowGap * 2;
}

/// Pointer-driven reorder for one block of explorer rows.
///
/// The drop slot is mapped straight from the pointer: the pointer crossing a
/// row's middle moves the slot by one row, in both directions, so the dashed
/// marker follows the pointer the moment it enters the next row — the same
/// model as the HTML prototype's .ex-shade ("the dashed slot marks the
/// landing position"). Flutter's [ReorderableListView] instead derives the
/// target from the drag start, and its gap needs roughly a full row of extra
/// travel before it moves, which reads as "the highlight is stuck in the
/// bottom rows".
///
/// While a row is lifted the list itself does not change shape: the source
/// row stays mounted (hidden) so its pointer recogniser keeps owning the
/// drag, and both the flying row and the dashed slot live in the overlay.
class SessionReorderList extends StatefulWidget {
  const SessionReorderList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
    required this.metrics,
  });

  final int itemCount;
  final Widget Function(
    BuildContext context,
    int index,
    SessionReorderController controller,
  )
  itemBuilder;

  /// Receives the framework's pre-removal indices: the item that moved from
  /// oldIndex should be inserted before newIndex (so callers subtract one
  /// when moving an item downwards), matching ReorderableListView so the
  /// page's existing handlers stay untouched.
  final ReorderCallback onReorder;

  final SessionRowMetrics metrics;

  @override
  State<SessionReorderList> createState() => _SessionReorderListState();
}

/// Hands one row drag's pointer stream to its [SessionReorderList].
class SessionReorderController {
  _SessionReorderListState? _state;

  /// Index of the row currently lifted, or null; row widgets listen to this
  /// to hide themselves while they fly in the overlay.
  final ValueNotifier<int?> dragging = ValueNotifier<int?>(null);

  void begin(int index, Offset globalPosition) =>
      _state?._begin(index, globalPosition);

  void update(Offset globalPosition) => _state?._update(globalPosition);

  void end() => _state?._end();

  void cancel() => _state?._cancel();
}

/// The pan surface that lifts a row. A press without movement stays a tap for
/// the row's own [InkWell]; only a drag hands the pointer to [controller].
class RowDragSurface extends StatelessWidget {
  const RowDragSurface({
    super.key,
    required this.index,
    required this.controller,
    required this.child,
    this.cursor,
  });

  final int index;
  final SessionReorderController? controller;
  final MouseCursor? cursor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final SessionReorderController? drag = controller;
    if (drag == null) {
      return child;
    }
    return MouseRegion(
      cursor: cursor ?? MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (DragStartDetails details) =>
            drag.begin(index, details.globalPosition),
        onPanUpdate: (DragUpdateDetails details) =>
            drag.update(details.globalPosition),
        onPanEnd: (_) => drag.end(),
        onPanCancel: drag.cancel,
        child: child,
      ),
    );
  }
}

class _SessionReorderListState extends State<SessionReorderList> {
  final SessionReorderController _controller = SessionReorderController();

  /// The lifted row renders through this controller: it is never attached to
  /// the list, so the copy stays visible while the source row hides itself.
  final SessionReorderController _floatController = SessionReorderController();
  int? _dragIndex;

  /// Final position of the lifted row: how many of the other rows' middles
  /// sit above the pointer, in 0..itemCount - 1.
  int? _dropIndex;

  double _grabDy = 0;
  List<Rect> _grid = const <Rect>[];
  OverlayEntry? _overlay;
  ValueNotifier<double>? _floatTop;

  @override
  void initState() {
    super.initState();
    _controller._state = this;
  }

  @override
  void didUpdateWidget(covariant SessionReorderList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragIndex != null && widget.itemCount != oldWidget.itemCount) {
      // The list changed under the drag (a session closed): drop the drag
      // rather than reorder against stale indices.
      _cancel();
    }
  }

  @override
  void dispose() {
    _controller._state = null;
    _controller.dragging.dispose();
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The list keeps its exact shape while a row is lifted: the source row
    // hides itself and both the flying row and the drop slot render in the
    // overlay, so no element is unmounted mid-drag.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < widget.itemCount; i++)
          widget.itemBuilder(context, i, _controller),
      ],
    );
  }

  /// Global rects of the row slots, measured once when the drag starts: the
  /// drop mapping keeps using this grid for the whole drag.
  List<Rect> _measureRows() {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return const <Rect>[];
    }
    final List<Rect> rects = <Rect>[];
    box.visitChildren((RenderObject child) {
      if (child is RenderBox && child.hasSize) {
        rects.add(child.localToGlobal(Offset.zero) & child.size);
      }
    });
    return rects;
  }

  void _begin(int index, Offset globalPosition) {
    if (_dragIndex != null || index < 0 || index >= widget.itemCount) {
      return;
    }
    final List<Rect> grid = _measureRows();
    if (grid.length != widget.itemCount) {
      return;
    }
    _grid = grid;
    _dragIndex = index;
    _dropIndex = _dropFor(globalPosition.dy);
    _grabDy = (globalPosition.dy - grid[index].top).clamp(
      0.0,
      grid[index].height,
    );
    _floatTop = ValueNotifier<double>(globalPosition.dy - _grabDy);
    final Widget floatChild = widget.itemBuilder(
      context,
      index,
      _floatController,
    );
    _overlay = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return Positioned.fill(
          child: MouseRegion(
            cursor: SystemMouseCursors.grabbing,
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _floatTop!,
                builder: (BuildContext context, double top, Widget? child) {
                  return Stack(
                    children: <Widget>[
                      _positionedShade(),
                      Positioned(
                        left: grid[index].left,
                        top: top,
                        width: grid[index].width,
                        height: grid[index].height,
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
                child: Material(color: Colors.transparent, child: floatChild),
              ),
            ),
          ),
        );
      },
    );
    _controller.dragging.value = index;
    Overlay.of(context).insert(_overlay!);
  }

  Widget _positionedShade() {
    final Rect? rect = _shadeRect();
    if (rect == null) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: _DropShade(
        key: sessionDropShadeKey,
        metrics: widget.metrics,
        slotHeight: rect.height,
      ),
    );
  }

  Rect? _shadeRect() {
    final int? drop = _dropIndex;
    if (drop == null || drop < 0 || drop >= _grid.length) {
      return null;
    }
    return _grid[drop];
  }

  void _update(Offset globalPosition) {
    if (_dragIndex == null) {
      return;
    }
    final int next = _dropFor(globalPosition.dy);
    _dropIndex = next;
    _floatTop?.value = globalPosition.dy - _grabDy;
  }

  /// How many of the other rows' middles sit above the pointer: the pointer
  /// strictly below a row's centre means it has moved past that row.
  int _dropFor(double pointerY) {
    var to = 0;
    for (var i = 0; i < _grid.length; i++) {
      if (i == _dragIndex) {
        continue;
      }
      if (pointerY > _grid[i].center.dy) {
        to += 1;
      }
    }
    return to;
  }

  void _end() {
    final int? from = _dragIndex;
    final int? to = _dropIndex;
    _finish();
    if (from != null && to != null && to != from) {
      widget.onReorder(from, to >= from ? to + 1 : to);
    }
  }

  void _cancel() {
    if (_dragIndex == null) {
      return;
    }
    _finish();
  }

  void _finish() {
    _removeOverlay();
    _controller.dragging.value = null;
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay?.dispose();
    _overlay = null;
    _floatTop?.dispose();
    _floatTop = null;
  }
}

/// The dashed landing slot: .ex-shade.in-row in the prototype.
class _DropShade extends StatelessWidget {
  const _DropShade({
    super.key,
    required this.metrics,
    required this.slotHeight,
  });

  final SessionRowMetrics metrics;
  final double slotHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: slotHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.rowLeft,
          metrics.rowGap,
          metrics.rowRight,
          metrics.rowGap,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.10),
          ),
          child: CustomPaint(
            foregroundPainter: _DashedBorderPainter(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const double dash = 3;
    const double gap = 2;
    void dashedLine(Offset from, Offset to) {
      final double total = (to - from).distance;
      if (total <= 0) {
        return;
      }
      final Offset step = (to - from) / total;
      var travelled = 0.0;
      while (travelled < total) {
        final double end = (travelled + dash).clamp(0.0, total);
        canvas.drawLine(from + step * travelled, from + step * end, paint);
        travelled += dash + gap;
      }
    }

    final Rect rect = Offset.zero & size;
    dashedLine(rect.topLeft, rect.topRight);
    dashedLine(rect.topRight, rect.bottomRight);
    dashedLine(rect.bottomRight, rect.bottomLeft);
    dashedLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
