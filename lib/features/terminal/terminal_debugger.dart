import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' as xterm;

/// Debugging utilities for terminal rendering issues
class TerminalDebugger {
  static bool enableDebugLogs = false;

  /// Check if the terminal's scroll position is valid
  static void checkScrollPosition(ScrollController controller, String context) {
    if (!enableDebugLogs) return;

    final position = controller.position;
    debugPrint('[$context] Scroll Debug:');
    debugPrint('  - pixels: ${position.pixels}');
    debugPrint('  - minScrollExtent: ${position.minScrollExtent}');
    debugPrint('  - maxScrollExtent: ${position.maxScrollExtent}');
    debugPrint('  - viewportDimension: ${position.viewportDimension}');
    debugPrint('  - isInfinite: ${position.maxScrollExtent.isInfinite}');
  }

  /// Check terminal buffer state
  static void checkTerminalState(xterm.Terminal terminal, String context) {
    if (!enableDebugLogs) return;

    debugPrint('[$context] Terminal Debug:');
    debugPrint('  - isUsingAltBuffer: ${terminal.isUsingAltBuffer}');
    debugPrint('  - buffer.lines.length: ${terminal.buffer.lines.length}');
    debugPrint('  - viewHeight: ${terminal.viewHeight}');
    debugPrint('  - viewWidth: ${terminal.viewWidth}');
    debugPrint('  - cursorY: ${terminal.buffer.cursorY}');
  }

  /// Analyze ANSI sequences in text
  static Map<String, int> analyzeAnsiSequences(String text) {
    final sequences = <String, int>{};
    final regex = RegExp(r'\x1b\[([0-9;]*)m');

    for (final match in regex.allMatches(text)) {
      final code = match.group(1) ?? '';
      sequences[code] = (sequences[code] ?? 0) + 1;
    }

    return sequences;
  }

  /// Get human-readable ANSI code descriptions
  static String getAnsiDescription(String code) {
    switch (code) {
      case '0': return 'Reset';
      case '1': return 'Bold';
      case '2': return 'Faint';
      case '3': return 'Italic';
      case '4': return 'Underline';
      case '7': return 'Inverse';
      case '22': return 'Normal intensity';
      case '23': return 'Not italic';
      case '24': return 'Not underlined';
      case '27': return 'Not inverse';
      default: return 'Other ($code)';
    }
  }

  /// Log ANSI sequence statistics
  static void logAnsiStatistics(String text, String context) {
    if (!enableDebugLogs) return;

    final sequences = analyzeAnsiSequences(text);
    if (sequences.isEmpty) return;

    debugPrint('[$context] ANSI Sequences:');
    sequences.forEach((code, count) {
      debugPrint('  - ${getAnsiDescription(code)}: $count times');
    });

    // Check for potential underline issues
    final underlineCount = sequences['4'] ?? 0;
    final resetCount = sequences['0'] ?? 0;
    final notUnderlinedCount = sequences['24'] ?? 0;

    if (underlineCount > 0) {
      debugPrint('  ⚠️  Underline analysis:');
      debugPrint('     - Underline set: $underlineCount');
      debugPrint('     - Reset all: $resetCount');
      debugPrint('     - Underline off: $notUnderlinedCount');

      if (underlineCount > resetCount + notUnderlinedCount) {
        debugPrint('     - ⚠️  WARNING: More underline-on than underline-off!');
      }
    }
  }
}
