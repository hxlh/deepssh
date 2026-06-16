import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/core.dart';

/// Routes mouse-wheel scrolling for the terminal.
///
/// Behavior:
///  - Main buffer, or alternate buffer that has accumulated scrollback
///    (streaming apps, e.g. `seq`, `cat`): the terminal's native Scrollable
///    scrolls the real history directly.
///  - Alternate buffer with NO scrollback (full-screen redraw TUIs that paint
///    the screen in place, e.g. vim, less, Claude Code's UI): wheel events are
///    captured directly and converted to mouse / arrow-key events sent to the
///    application, which then scrolls its own view. This is the only way to
///    scroll such apps, since the terminal buffer holds only the current
///    screen.
///
/// The app-routing path uses a raw [Listener.onPointerSignal] rather than a
/// nested infinite [Scrollable], because a nested Scrollable whose inner
/// viewport has maxScrollExtent == 0 absorbs the wheel event and the outer
/// scrollable never sees it — which silently broke wheel forwarding for
/// full-screen TUIs.
class TerminalScrollGestureHandler extends StatefulWidget {
  const TerminalScrollGestureHandler({
    super.key,
    required this.terminal,
    required this.getCellOffset,
    required this.getLineHeight,
    this.simulateScroll = true,
    required this.child,
  });

  final Terminal terminal;

  /// Returns the cell offset for the pixel offset.
  final CellOffset Function(Offset) getCellOffset;

  /// Returns the pixel height of lines in the terminal.
  final double Function() getLineHeight;

  /// Whether to simulate scroll events in the terminal when the application
  /// doesn't declare it supports mouse wheel events. true by default as it
  /// is the default behavior of most terminals.
  final bool simulateScroll;

  final Widget child;

  @override
  State<TerminalScrollGestureHandler> createState() =>
      _TerminalScrollGestureHandlerState();
}

class _TerminalScrollGestureHandlerState
    extends State<TerminalScrollGestureHandler> {
  /// Whether the application is in the alternate screen buffer.
  var isAltBuffer = false;

  /// Whether the current buffer has scrollback history that the native
  /// Scrollable can scroll through.
  var hasScrollback = false;

  /// The last pointer position where a scroll gesture happened, used to
  /// compute the cell offset of the terminal mouse event.
  var lastPointerPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    widget.terminal.addListener(_onTerminalUpdated);
    _refreshState();
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_onTerminalUpdated);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TerminalScrollGestureHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onTerminalUpdated);
      widget.terminal.addListener(_onTerminalUpdated);
      _refreshState();
    }
  }

  void _refreshState() {
    isAltBuffer = widget.terminal.isUsingAltBuffer;
    hasScrollback =
        widget.terminal.buffer.lines.length > widget.terminal.viewHeight;
  }

  void _onTerminalUpdated() {
    final wasRoutingToApp = isAltBuffer && !hasScrollback;
    _refreshState();
    final routeToApp = isAltBuffer && !hasScrollback;
    if (wasRoutingToApp != routeToApp) {
      setState(() {});
    }
  }

  /// True when wheel events should be sent to the application instead of
  /// scrolling the terminal's native scrollback.
  bool get _routeWheelToApp => isAltBuffer && !hasScrollback;

  /// Send a single scroll event to the terminal. If [simulateScroll] is true,
  /// then if the application doesn't recognize mouse wheel events, this method
  /// will simulate scroll events by sending up/down arrow keys.
  void _sendScrollEvent(bool up) {
    final position = widget.getCellOffset(lastPointerPosition);

    final handled = widget.terminal.mouseInput(
      up ? TerminalMouseButton.wheelUp : TerminalMouseButton.wheelDown,
      TerminalMouseButtonState.down,
      position,
    );

    if (!handled && widget.simulateScroll) {
      widget.terminal.keyInput(
        up ? TerminalKey.arrowUp : TerminalKey.arrowDown,
      );
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (event.kind != PointerDeviceKind.mouse) return;

    lastPointerPosition = event.position;

    // PointerScrollEvent.scrollDelta.dy follows the platform convention:
    //   dy > 0 => user spun the wheel DOWN (wants content below)
    //   dy < 0 => user spun the wheel UP   (wants content above)
    final lineHeight = widget.getLineHeight();
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    final up = dy < 0;
    var count = (dy.abs() / lineHeight).round();
    if (count < 1) count = 1;
    for (var i = 0; i < count; i++) {
      _sendScrollEvent(up);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full-screen redraw TUI with no scrollback: capture the wheel directly
    // and forward mouse/arrow events to the app so it can scroll its own view.
    // Everything else (main buffer, or alt buffer that has scrollback) uses
    // the native Scrollable.
    if (!_routeWheelToApp) {
      return widget.child;
    }

    return Listener(
      onPointerSignal: _onPointerSignal,
      onPointerDown: (event) {
        lastPointerPosition = event.position;
      },
      child: widget.child,
    );
  }
}
