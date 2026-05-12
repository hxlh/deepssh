import 'package:test/test.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('Buffer.getText()', () {
    test('should return the text', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.getText(), startsWith('Hello World'));
    });

    test('can handle line wrap', () {
      final terminal = Terminal();
      terminal.resize(10, 10);

      final line1 = 'This is a long line that should wrap';
      final line2 = 'This is a short line';
      final line3 = 'This is a long long long long line that should wrap';
      final line4 = 'Short';

      terminal.write('$line1\r\n');
      terminal.write('$line2\r\n');
      terminal.write('$line3\r\n');
      terminal.write('$line4\r\n');

      final lines = terminal.buffer.getText().split('\n');
      expect(lines[0], line1);
      expect(lines[1], line2);
      expect(lines[2], line3);
      expect(lines[3], line4);
    });

    test('can handle negative start', () {
      final terminal = Terminal();

      terminal.write('Hello World');

      expect(
        terminal.buffer.getText(
          BufferRangeLine(CellOffset(-100, -100), CellOffset(100, 100)),
        ),
        startsWith('Hello World'),
      );
    });

    test('can handle invalid end', () {
      final terminal = Terminal();

      terminal.write('Hello World');

      expect(
        terminal.buffer.getText(
          BufferRangeLine(CellOffset(0, 0), CellOffset(100, 100)),
        ),
        startsWith('Hello World'),
      );
    });

    test('can handle reversed range', () {
      final terminal = Terminal();

      terminal.write('Hello World');

      expect(
        terminal.buffer.getText(
          BufferRangeLine(CellOffset(5, 5), CellOffset(0, 0)),
        ),
        startsWith('Hello World'),
      );
    });

    test('can handle block range', () {
      final terminal = Terminal();

      terminal.write('Hello World\r\n');
      terminal.write('Nice to meet you\r\n');

      expect(
        terminal.buffer.getText(
          BufferRangeBlock(CellOffset(2, 0), CellOffset(5, 1)),
        ),
        startsWith('llo\nce '),
      );
    });
  });

  group('Buffer.resize()', () {
    test('should resize the buffer', () {
      final terminal = Terminal();
      terminal.resize(10, 10);

      expect(terminal.viewWidth, 10);
      expect(terminal.viewHeight, 10);

      for (var i = 0; i < terminal.lines.length; i++) {
        final line = terminal.lines[i];
        expect(line.length, 10);
      }

      terminal.resize(20, 20);

      expect(terminal.viewWidth, 20);
      expect(terminal.viewHeight, 20);

      for (var i = 0; i < terminal.lines.length; i++) {
        final line = terminal.lines[i];
        expect(line.length, 20);
      }
    });
  });

  group('Buffer.deleteLines()', () {
    test('works', () {
      final terminal = Terminal();
      terminal.resize(10, 10);

      for (var i = 1; i <= 10; i++) {
        terminal.write('line$i');

        if (i < 10) {
          terminal.write('\r\n');
        }
      }

      terminal.setMargins(3, 7);
      terminal.setCursor(0, 5);

      terminal.buffer.deleteLines(1);

      expect(terminal.buffer.lines[2].toString(), 'line3');
      expect(terminal.buffer.lines[3].toString(), 'line4');
      expect(terminal.buffer.lines[4].toString(), 'line5');
      expect(terminal.buffer.lines[5].toString(), 'line7');
      expect(terminal.buffer.lines[6].toString(), 'line8');
      expect(terminal.buffer.lines[7].toString(), '');
      expect(terminal.buffer.lines[8].toString(), 'line9');
      expect(terminal.buffer.lines[9].toString(), 'line10');
    });
  });

  group('Buffer.insertLines()', () {
    test('works', () {
      final terminal = Terminal();

      for (var i = 0; i < 10; i++) {
        terminal.write('line$i\r\n');
      }

      print(terminal.buffer);

      terminal.setMargins(2, 6);
      terminal.setCursor(0, 4);

      print(terminal.buffer.absoluteCursorY);

      terminal.buffer.insertLines(1);

      print(terminal.buffer);

      expect(terminal.buffer.lines[3].toString(), 'line3');
      expect(terminal.buffer.lines[4].toString(), ''); // inserted
      expect(terminal.buffer.lines[5].toString(), 'line4'); // moved
      expect(terminal.buffer.lines[6].toString(), 'line5'); // moved
      expect(terminal.buffer.lines[7].toString(), 'line7');
    });

    test('has no effect if cursor is out of scroll region', () {
      final terminal = Terminal();

      for (var i = 0; i < 10; i++) {
        terminal.write('line$i\r\n');
      }

      terminal.setMargins(2, 6);
      terminal.setCursor(0, 1);

      terminal.buffer.insertLines(1);

      expect(terminal.buffer.lines[2].toString(), 'line2');
      expect(terminal.buffer.lines[3].toString(), 'line3');
      expect(terminal.buffer.lines[4].toString(), 'line4');
      expect(terminal.buffer.lines[5].toString(), 'line5');
      expect(terminal.buffer.lines[6].toString(), 'line6');
      expect(terminal.buffer.lines[7].toString(), 'line7');
    });
  });

  group('Buffer.getWordBoundary supports custom word separators', () {
    test('can set word separators', () {
      final terminal = Terminal(wordSeparators: {'o'.codeUnitAt(0)});

      terminal.write('Hello World');

      expect(
        terminal.mainBuffer.getWordBoundary(CellOffset(0, 0)),
        BufferRangeLine(CellOffset(0, 0), CellOffset(4, 0)),
      );

      expect(
        terminal.mainBuffer.getWordBoundary(CellOffset(5, 0)),
        BufferRangeLine(CellOffset(5, 0), CellOffset(7, 0)),
      );
    });
  });

  test('does not delete lines beyond the scroll region', () {
    final terminal = Terminal();
    terminal.resize(10, 10);

    for (var i = 1; i <= 10; i++) {
      terminal.write('line$i');

      if (i < 10) {
        terminal.write('\r\n');
      }
    }

    terminal.setMargins(3, 7);
    terminal.setCursor(0, 5);

    terminal.buffer.deleteLines(20);

    expect(terminal.buffer.lines[2].toString(), 'line3');
    expect(terminal.buffer.lines[3].toString(), 'line4');
    expect(terminal.buffer.lines[4].toString(), 'line5');
    expect(terminal.buffer.lines[5].toString(), '');
    expect(terminal.buffer.lines[6].toString(), '');
    expect(terminal.buffer.lines[7].toString(), '');
    expect(terminal.buffer.lines[8].toString(), 'line9');
    expect(terminal.buffer.lines[9].toString(), 'line10');
  });

  group('Buffer.eraseDisplayFromCursor()', () {
    test('works', () {
      final terminal = Terminal();
      terminal.resize(3, 3);
      terminal.write('123\r\n456\r\n789');

      terminal.setCursor(1, 1);
      terminal.buffer.eraseDisplayFromCursor();

      expect(terminal.buffer.lines[0].toString(), '123');
      expect(terminal.buffer.lines[1].toString(), '4');
      expect(terminal.buffer.lines[2].toString(), '');
    });
  });

  group('Buffer.scrollUp()', () {
    test('does not detach anchors on moved lines', () {
      final terminal = Terminal();
      terminal.resize(10, 10);

      for (var i = 0; i < 10; i++) {
        terminal.write('line$i\r\n');
      }

      final anchorLine1 = terminal.buffer.lines[1].createAnchor(0);
      final anchorLine2 = terminal.buffer.lines[2].createAnchor(0);
      final anchorLine3 = terminal.buffer.lines[3].createAnchor(0);

      expect(anchorLine1.attached, true);
      expect(anchorLine2.attached, true);
      expect(anchorLine3.attached, true);

      terminal.setMargins(0, 9);
      terminal.buffer.scrollUp(1);

      expect(anchorLine1.attached, true);
      expect(anchorLine2.attached, true);
      expect(anchorLine3.attached, true);

      expect(anchorLine1.y, 0);
      expect(anchorLine2.y, 1);
      expect(anchorLine3.y, 2);
    });
  });

  group('Buffer.scrollDown()', () {
    test('does not detach anchors on moved lines', () {
      final terminal = Terminal();
      terminal.resize(10, 10);

      for (var i = 0; i < 10; i++) {
        terminal.write('line$i\r\n');
      }

      final anchorLine6 = terminal.buffer.lines[6].createAnchor(0);
      final anchorLine7 = terminal.buffer.lines[7].createAnchor(0);
      final anchorLine8 = terminal.buffer.lines[8].createAnchor(0);

      expect(anchorLine6.attached, true);
      expect(anchorLine7.attached, true);
      expect(anchorLine8.attached, true);

      terminal.setMargins(0, 9);
      terminal.buffer.scrollDown(1);

      expect(anchorLine6.attached, true);
      expect(anchorLine7.attached, true);
      expect(anchorLine8.attached, true);

      expect(anchorLine6.y, 7);
      expect(anchorLine7.y, 8);
      expect(anchorLine8.y, 9);
    });
  });

  group('Buffer.deleteLines()', () {
    test('does not detach anchors on moved lines', () {
      final terminal = Terminal();
      terminal.resize(10, 10);

      for (var i = 0; i < 10; i++) {
        terminal.write('line$i\r\n');
      }

      final anchorLine5 = terminal.buffer.lines[5].createAnchor(0);
      final anchorLine6 = terminal.buffer.lines[6].createAnchor(0);
      final anchorLine7 = terminal.buffer.lines[7].createAnchor(0);

      expect(anchorLine5.attached, true);
      expect(anchorLine6.attached, true);
      expect(anchorLine7.attached, true);

      terminal.setMargins(3, 8);
      terminal.setCursor(0, 5);
      terminal.buffer.deleteLines(2);

      expect(anchorLine5.attached, true);
      expect(anchorLine6.attached, true);
      expect(anchorLine7.attached, true);

      expect(anchorLine5.y, 5);
      expect(anchorLine6.y, 6);
      expect(anchorLine7.y, 6); // line7 moved up to fill deleted gap
    });
  });

  group('Buffer.insertLines()', () {
    test('does not detach anchors on moved lines', () {
      final terminal = Terminal();
      terminal.resize(10, 10);

      for (var i = 0; i < 10; i++) {
        terminal.write('line$i\r\n');
      }

      final anchorLine5 = terminal.buffer.lines[5].createAnchor(0);
      final anchorLine6 = terminal.buffer.lines[6].createAnchor(0);
      final anchorLine7 = terminal.buffer.lines[7].createAnchor(0);

      expect(anchorLine5.attached, true);
      expect(anchorLine6.attached, true);
      expect(anchorLine7.attached, true);

      terminal.setMargins(3, 8);
      terminal.setCursor(0, 5);
      terminal.buffer.insertLines(2);

      expect(anchorLine5.attached, true);
      expect(anchorLine6.attached, true);
      expect(anchorLine7.attached, true);

      expect(anchorLine5.y, 7);
      expect(anchorLine6.y, 8);
      expect(anchorLine7.y, 9);
    });
  });
}
