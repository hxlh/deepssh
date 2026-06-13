import 'package:flutter/widgets.dart';
import 'package:xterm/core.dart';
import 'package:xterm/src/ui/infinite_scroll_view.dart';

/// Routes mouse-wheel scrolling for the terminal.
///
/// Behavior:
///  - Main buffer, or alternate buffer that has accumulated scrollback
///    (streaming apps, e.g. `seq`, `cat`, Claude Code's streaming output):
///    the terminal's native Scrollable scrolls the real history directly.
///  - Alternate buffer with NO scrollback (full-screen redraw TUIs that paint
///    the screen in place, e.g. vim, less, Claude Code's UI): wheel events are
///    converted to mouse / arrow-key events and sent to the application, which
///    then scrolls its own view. This is the only way to scroll such apps,
///    since the terminal buffer holds only the current screen.
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

  /// The line offset tracked across scroll events, used to compute how many
  /// scroll events to send to the terminal.
  var lastLineOffset = 0;

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
      // Only the widget tree shape changed (native scroll <-> app routing),
      // so rebuild when the routing decision flips.
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

  void _onScroll(double offset) {
    final currentLineOffset = offset ~/ widget.getLineHeight();

    final delta = currentLineOffset - lastLineOffset;

    for (var i = 0; i < delta.abs(); i++) {
      _sendScrollEvent(delta < 0);
    }

    lastLineOffset = currentLineOffset;
  }

  @override
  Widget build(BuildContext context) {
    // Full-screen redraw TUI with no scrollback: route wheel to the app so it
    // can scroll its own view. Everything else (main buffer, or alt buffer
    // that has accumulated scrollback) uses the native Scrollable.
    if (!_routeWheelToApp) {
      return widget.child;
    }

    return Listener(
      onPointerSignal: (event) {
        lastPointerPosition = event.position;
      },
      onPointerDown: (event) {
        lastPointerPosition = event.position;
      },
      child: InfiniteScrollView(
        onScroll: _onScroll,
        child: widget.child,
      ),
    );
  }
}
