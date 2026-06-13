import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' as xterm;

/// Enhanced debugging for scrolling issues on Windows
class TerminalScrollDebugger {
  static bool enableVerboseDebug = false;

  /// Log detailed scroll state
  static void logDetailedScrollState(
    ScrollController? controller,
    xterm.Terminal terminal,
    String context,
  ) {
    if (!enableVerboseDebug) return;

    debugPrint('═══════════════════════════════════════');
    debugPrint('[$context] Detailed Scroll State');
    debugPrint('═══════════════════════════════════════');

    if (controller == null) {
      debugPrint('❌ ScrollController is null!');
      return;
    }

    if (!controller.hasClients) {
      debugPrint('❌ ScrollController has no clients!');
      return;
    }

    final position = controller.position;
    debugPrint('ScrollPosition:');
    debugPrint('  - pixels: ${position.pixels}');
    debugPrint('  - minScrollExtent: ${position.minScrollExtent}');
    debugPrint('  - maxScrollExtent: ${position.maxScrollExtent}');
    debugPrint('  - viewportDimension: ${position.viewportDimension}');
    debugPrint('  - extentBefore: ${position.extentBefore}');
    debugPrint('  - extentAfter: ${position.extentAfter}');
    debugPrint('  - extentInside: ${position.extentInside}');
    debugPrint('  - atEdge: ${position.atEdge}');
    debugPrint('  - outOfRange: ${position.outOfRange}');

    debugPrint('');
    debugPrint('Computed values:');
    debugPrint('  - isInfinite: ${position.maxScrollExtent.isInfinite}');
    debugPrint('  - isFinite: ${position.maxScrollExtent.isFinite}');
    debugPrint('  - scrollRange: ${position.maxScrollExtent - position.minScrollExtent}');
    debugPrint('  - canScroll: ${position.maxScrollExtent > position.minScrollExtent}');

    debugPrint('');
    debugPrint('Terminal state:');
    debugPrint('  - isUsingAltBuffer: ${terminal.isUsingAltBuffer}');
    debugPrint('  - buffer.lines.length: ${terminal.buffer.lines.length}');
    debugPrint('  - viewHeight: ${terminal.viewHeight}');
    debugPrint('  - viewWidth: ${terminal.viewWidth}');

    debugPrint('═══════════════════════════════════════');
  }

  /// Check if scroll is actually working
  static bool testScroll(ScrollController? controller) {
    if (controller == null || !controller.hasClients) {
      debugPrint('⚠️  Cannot test scroll: controller not ready');
      return false;
    }

    final position = controller.position;
    final canScroll = position.maxScrollExtent > position.minScrollExtent;

    if (!canScroll) {
      debugPrint('❌ Scroll test failed:');
      debugPrint('   maxScrollExtent: ${position.maxScrollExtent}');
      debugPrint('   minScrollExtent: ${position.minScrollExtent}');
      debugPrint('   Difference: ${position.maxScrollExtent - position.minScrollExtent}');

      if (position.maxScrollExtent.isInfinite) {
        debugPrint('   ⚠️  PROBLEM: maxScrollExtent is INFINITE!');
        debugPrint('   This means InfiniteScrollView is active.');
        debugPrint('   Check scroll_handler.dart alternate buffer detection.');
      } else if (position.maxScrollExtent == 0) {
        debugPrint('   ⚠️  PROBLEM: maxScrollExtent is 0!');
        debugPrint('   Content may not be long enough, or viewport is too large.');
      }
    } else {
      debugPrint('✅ Scroll test passed: can scroll ${position.maxScrollExtent} pixels');
    }

    return canScroll;
  }

  /// Create a test report
  static String generateReport(
    ScrollController? controller,
    xterm.Terminal terminal,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('DeepSSH Scroll Diagnostic Report');
    buffer.writeln('================================');
    buffer.writeln('');

    if (controller == null) {
      buffer.writeln('ERROR: ScrollController is null');
      return buffer.toString();
    }

    if (!controller.hasClients) {
      buffer.writeln('ERROR: ScrollController has no clients');
      buffer.writeln('The scroll controller is not attached to a scrollable widget.');
      return buffer.toString();
    }

    final position = controller.position;
    buffer.writeln('Scroll Position:');
    buffer.writeln('  Current: ${position.pixels.toStringAsFixed(2)}');
    buffer.writeln('  Min: ${position.minScrollExtent.toStringAsFixed(2)}');
    buffer.writeln('  Max: ${position.maxScrollExtent.toStringAsFixed(2)}');
    buffer.writeln('  Viewport: ${position.viewportDimension.toStringAsFixed(2)}');
    buffer.writeln('');

    final canScroll = position.maxScrollExtent > position.minScrollExtent;
    buffer.writeln('Can Scroll: ${canScroll ? "YES ✓" : "NO ✗"}');

    // Check for alternate buffer mode
    final isAltBuffer = terminal.isUsingAltBuffer;
    final hasScrollback = terminal.buffer.lines.length > terminal.viewHeight;
    final routeWheelToApp = isAltBuffer && !hasScrollback;
    buffer.writeln('');
    buffer.writeln('Terminal Mode:');
    buffer.writeln('  Using Alt Buffer: ${isAltBuffer ? "YES" : "NO"}');
    buffer.writeln('  Lines in buffer: ${terminal.buffer.lines.length}');
    buffer.writeln('  View size: ${terminal.viewWidth}x${terminal.viewHeight}');
    buffer.writeln('  Cursor: (${terminal.buffer.cursorX}, ${terminal.buffer.cursorY})');
    buffer.writeln('  Mouse Mode: ${terminal.mouseMode}  (none = app does NOT report mouse)');
    buffer.writeln('  Has Scrollback: ${hasScrollback ? "YES" : "NO"}');
    buffer.writeln(
      '  Wheel Routing: ${routeWheelToApp ? "to APP (vim/Claude Code style)" : "NATIVE scrollback"}',
    );
    buffer.writeln('');
    buffer.writeln('Mouse Passthrough (scroll the wheel a few times first):');
    buffer.writeln('  mouseInput calls: ${terminal.debugMouseInputCalls}');
    buffer.writeln(
      '  sent to SSH: ${terminal.debugMouseInputHandled}  (calls that produced output)',
    );
    buffer.writeln('  last mouse cell: ${terminal.debugLastMouseCell}');

    if (!canScroll) {
      buffer.writeln('');
      buffer.writeln('DIAGNOSIS:');
      if (position.maxScrollExtent.isInfinite) {
        buffer.writeln('  ❌ Infinite scroll detected!');
        buffer.writeln('  ⚠️  InfiniteScrollView is incorrectly active.');
        if (!isAltBuffer) {
          buffer.writeln('  ⚠️  BUT terminal is NOT in alt buffer mode!');
          buffer.writeln('  ⚠️  This is the BUG: InfiniteScrollView should only');
          buffer.writeln('  ⚠️  be active in alt buffer (vim, less, etc.)');
        } else {
          buffer.writeln('  ⚠️  Alt buffer is active, but you\'re trying to scroll');
          buffer.writeln('  ⚠️  in a full-screen app. These apps don\'t need scrolling.');
        }
        buffer.writeln('  Fix: Check scroll_handler.dart line 119');
      } else if (position.maxScrollExtent == 0) {
        buffer.writeln('  ❌ Zero scroll extent!');
        buffer.writeln('  Content lines: ${terminal.buffer.lines.length}');
        buffer.writeln('  Viewport height: ${terminal.viewHeight}');
        if (isAltBuffer) {
          buffer.writeln('  Note: Alt buffer apps fill the screen,');
          buffer.writeln('        so maxScrollExtent=0 is expected.');
        } else {
          buffer.writeln('  Possible cause: Content fits in viewport');
        }
      }
    } else if (isAltBuffer) {
      buffer.writeln('');
      buffer.writeln('WARNING:');
      buffer.writeln('  Terminal is in alt buffer mode (full-screen app)');
      buffer.writeln('  but scrolling is enabled. This is unusual.');
      buffer.writeln('  Most alt buffer apps (vim, less) don\'t use scrolling.');
    }

    buffer.writeln('');
    buffer.writeln('Terminal Info:');
    buffer.writeln('  Lines: ${terminal.buffer.lines.length}');
    buffer.writeln('  View: ${terminal.viewWidth}x${terminal.viewHeight}');
    buffer.writeln('  Alt Buffer: ${terminal.isUsingAltBuffer}');
    buffer.writeln('  Scrollback: ${terminal.buffer.scrollBack}');

    return buffer.toString();
  }
}
