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

    if (!canScroll) {
      buffer.writeln('');
      buffer.writeln('DIAGNOSIS:');
      if (position.maxScrollExtent.isInfinite) {
        buffer.writeln('  ❌ Infinite scroll detected!');
        buffer.writeln('  ⚠️  InfiniteScrollView is incorrectly active.');
        buffer.writeln('  ⚠️  Terminal alt buffer: ${terminal.isUsingAltBuffer}');
        buffer.writeln('  Fix: Check scroll_handler.dart line 119');
      } else if (position.maxScrollExtent == 0) {
        buffer.writeln('  ❌ Zero scroll extent!');
        buffer.writeln('  Content lines: ${terminal.buffer.lines.length}');
        buffer.writeln('  Viewport height: ${terminal.viewHeight}');
        buffer.writeln('  Possible cause: Content fits in viewport');
      }
    }

    buffer.writeln('');
    buffer.writeln('Terminal Info:');
    buffer.writeln('  Lines: ${terminal.buffer.lines.length}');
    buffer.writeln('  View: ${terminal.viewWidth}x${terminal.viewHeight}');
    buffer.writeln('  Alt Buffer: ${terminal.isUsingAltBuffer}');

    return buffer.toString();
  }
}
