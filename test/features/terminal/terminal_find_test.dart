import 'package:deepssh/features/terminal/terminal_find.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart' as xterm;

void main() {
  group('TerminalFindSession', () {
    late xterm.Terminal terminal;
    late xterm.TerminalController controller;
    late TerminalFindSession session;

    setUp(() {
      terminal = xterm.Terminal(maxLines: 100);
      controller = xterm.TerminalController();
      session = TerminalFindSession(
        terminal: terminal,
        terminalController: controller,
        searchHitBackground: Colors.yellow,
        searchHitBackgroundCurrent: Colors.orange,
      );
    });

    tearDown(() {
      session.dispose();
      controller.dispose();
    });

    test('maps matches after emoji to the correct terminal columns', () {
      terminal.resize(20, 1);
      terminal.write('😀target');

      session.setQuery('target');

      expect(session.matchCount, 1);
      final range = controller.highlights.single.range!;
      expect(range.begin.x, 2);
      expect(range.begin.y, 0);
      expect(range.end.x, 8);
      expect(range.end.y, 0);
    });

    test('searches across soft-wrapped lines without inserting newline', () {
      terminal.resize(5, 3);
      terminal.write('abcdefghij');

      session.setQuery('defghi');

      expect(session.matchCount, 1);
      final range = controller.highlights.single.range!;
      expect(range.begin.x, 3);
      expect(range.begin.y, 0);
      expect(range.end.x, 4);
      expect(range.end.y, 1);
    });

    test('does not match across hard line breaks', () {
      terminal.resize(10, 2);
      terminal.write('abc\r\ndef');

      session.setQuery('cde');

      expect(session.matchCount, 0);
    });
  });
}
