import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/mouse/button.dart';
import 'package:xterm/src/core/mouse/button_state.dart';
import 'package:xterm/src/terminal_view.dart';
import 'package:xterm/src/ui/controller.dart';
import 'package:xterm/src/ui/gesture/gesture_detector.dart';
import 'package:xterm/src/ui/pointer_input.dart';
import 'package:xterm/src/ui/render.dart';

class TerminalGestureHandler extends StatefulWidget {
  const TerminalGestureHandler({
    super.key,
    required this.terminalView,
    required this.terminalController,
    required this.scrollController,
    this.child,
    this.onTapUp,
    this.onSingleTapUp,
    this.onTapDown,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onTertiaryTapDown,
    this.onTertiaryTapUp,
    this.readOnly = false,
  });

  final TerminalViewState terminalView;

  final TerminalController terminalController;

  final ScrollController scrollController;

  final Widget? child;

  final GestureTapUpCallback? onTapUp;

  final GestureTapUpCallback? onSingleTapUp;

  final GestureTapDownCallback? onTapDown;

  final GestureTapDownCallback? onSecondaryTapDown;

  final GestureTapUpCallback? onSecondaryTapUp;

  final GestureTapDownCallback? onTertiaryTapDown;

  final GestureTapUpCallback? onTertiaryTapUp;

  final bool readOnly;

  @override
  State<TerminalGestureHandler> createState() => _TerminalGestureHandlerState();
}

class _TerminalGestureHandlerState extends State<TerminalGestureHandler> {
  static const _edgeAutoScrollZone = 32.0;
  static const _edgeAutoScrollTick = Duration(milliseconds: 50);
  static const _edgeAutoScrollPixelsPerTick = 32.0;

  TerminalViewState get terminalView => widget.terminalView;

  RenderTerminal get renderTerminal => terminalView.renderTerminal;

  CellOffset? _dragStartCell;

  Offset? _latestDragPosition;

  Timer? _edgeAutoScrollTimer;

  LongPressStartDetails? _lastLongPressStartDetails;

  @override
  Widget build(BuildContext context) {
    return TerminalGestureDetector(
      child: widget.child,
      onTapUp: widget.onTapUp,
      onSingleTapUp: onSingleTapUp,
      onTapDown: onTapDown,
      onSecondaryTapDown: onSecondaryTapDown,
      onSecondaryTapUp: onSecondaryTapUp,
      onTertiaryTapDown: onSecondaryTapDown,
      onTertiaryTapUp: onSecondaryTapUp,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      // onLongPressUp: onLongPressUp,
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onDragEnd: (_) => _endDragSelection(),
      onDragCancel: _endDragSelection,
      onDoubleTapDown: onDoubleTapDown,
    );
  }

  @override
  void dispose() {
    _stopEdgeAutoScroll();
    super.dispose();
  }

  bool get _shouldSendTapEvent =>
      !widget.readOnly &&
      widget.terminalController.shouldSendPointerInput(PointerInput.tap);

  void _tapDown(
    GestureTapDownCallback? callback,
    TapDownDetails details,
    TerminalMouseButton button, {
    bool forceCallback = false,
  }) {
    // Check if the terminal should and can handle the tap down event.
    var handled = false;
    if (_shouldSendTapEvent) {
      handled = renderTerminal.mouseEvent(
        button,
        TerminalMouseButtonState.down,
        details.localPosition,
      );
    }
    // If the event was not handled by the terminal, use the supplied callback.
    if (!handled || forceCallback) {
      callback?.call(details);
    }
  }

  void _tapUp(
    GestureTapUpCallback? callback,
    TapUpDetails details,
    TerminalMouseButton button, {
    bool forceCallback = false,
  }) {
    // Check if the terminal should and can handle the tap up event.
    var handled = false;
    if (_shouldSendTapEvent) {
      handled = renderTerminal.mouseEvent(
        button,
        TerminalMouseButtonState.up,
        details.localPosition,
      );
    }
    // If the event was not handled by the terminal, use the supplied callback.
    if (!handled || forceCallback) {
      callback?.call(details);
    }
  }

  void onTapDown(TapDownDetails details) {
    // onTapDown is special, as it will always call the supplied callback.
    // The TerminalView depends on it to bring the terminal into focus.
    _tapDown(
      widget.onTapDown,
      details,
      TerminalMouseButton.left,
      forceCallback: true,
    );
  }

  void onSingleTapUp(TapUpDetails details) {
    _tapUp(widget.onSingleTapUp, details, TerminalMouseButton.left);
  }

  void onSecondaryTapDown(TapDownDetails details) {
    _tapDown(widget.onSecondaryTapDown, details, TerminalMouseButton.right);
  }

  void onSecondaryTapUp(TapUpDetails details) {
    _tapUp(widget.onSecondaryTapUp, details, TerminalMouseButton.right);
  }

  void onTertiaryTapDown(TapDownDetails details) {
    _tapDown(widget.onTertiaryTapDown, details, TerminalMouseButton.middle);
  }

  void onTertiaryTapUp(TapUpDetails details) {
    _tapUp(widget.onTertiaryTapUp, details, TerminalMouseButton.right);
  }

  void onDoubleTapDown(TapDownDetails details) {
    renderTerminal.selectWord(details.localPosition);
  }

  void onLongPressStart(LongPressStartDetails details) {
    _lastLongPressStartDetails = details;
    renderTerminal.selectWord(details.localPosition);
  }

  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    renderTerminal.selectWord(
      _lastLongPressStartDetails!.localPosition,
      details.localPosition,
    );
  }

  // void onLongPressUp() {}

  void onDragStart(DragStartDetails details) {
    _dragStartCell = renderTerminal.getCellOffset(details.localPosition);
    _latestDragPosition = details.localPosition;

    details.kind == PointerDeviceKind.mouse
        ? renderTerminal.selectCharactersFromCell(_dragStartCell!)
        : renderTerminal.selectWord(details.localPosition);
  }

  void onDragUpdate(DragUpdateDetails details) {
    final dragStartCell = _dragStartCell;
    if (dragStartCell == null) return;
    _latestDragPosition = details.localPosition;
    renderTerminal.selectCharactersFromCell(
      dragStartCell,
      details.localPosition,
    );
    _updateEdgeAutoScroll();
  }

  void _updateEdgeAutoScroll() {
    final position = _latestDragPosition;
    if (position == null || !widget.scrollController.hasClients) {
      _stopEdgeAutoScroll();
      return;
    }

    final delta = _edgeAutoScrollDelta(position);
    if (delta == 0) {
      _stopEdgeAutoScroll();
      return;
    }

    _edgeAutoScrollTimer ??= Timer.periodic(
      _edgeAutoScrollTick,
      (_) => _autoScrollSelection(),
    );
  }

  double _edgeAutoScrollDelta(Offset position) {
    final height = renderTerminal.size.height;
    if (position.dy < _edgeAutoScrollZone) {
      return -_edgeAutoScrollPixelsPerTick;
    }
    if (position.dy > height - _edgeAutoScrollZone) {
      return _edgeAutoScrollPixelsPerTick;
    }
    return 0;
  }

  void _autoScrollSelection() {
    final dragStartCell = _dragStartCell;
    final latestPosition = _latestDragPosition;
    if (dragStartCell == null || latestPosition == null) {
      _stopEdgeAutoScroll();
      return;
    }

    final scrollPosition = widget.scrollController.position;
    final delta = _edgeAutoScrollDelta(latestPosition);
    if (delta == 0) {
      _stopEdgeAutoScroll();
      return;
    }

    final nextOffset = (scrollPosition.pixels + delta).clamp(
      scrollPosition.minScrollExtent,
      scrollPosition.maxScrollExtent,
    );
    if (nextOffset == scrollPosition.pixels) {
      return;
    }

    widget.scrollController.jumpTo(nextOffset);
    renderTerminal.selectCharactersFromCell(dragStartCell, latestPosition);
  }

  void _endDragSelection() {
    _dragStartCell = null;
    _latestDragPosition = null;
    _stopEdgeAutoScroll();
  }

  void _stopEdgeAutoScroll() {
    _edgeAutoScrollTimer?.cancel();
    _edgeAutoScrollTimer = null;
  }
}
