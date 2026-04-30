import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:xterm/xterm.dart';

@GenerateNiceMocks([MockSpec<EscapeHandler>()])
import 'parser_test.mocks.dart';

void main() {
  group('EscapeParser', () {
    test('can parse window manipulation', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[8;24;80t');
      verify(parser.handler.resize(80, 24));
    });

    test('can parse colon-separated truecolor foreground SGR', () {
      final parser = EscapeParser(MockEscapeHandler());
      parser.write('\x1b[38:2::255:128:64m');
      verify(parser.handler.setForegroundColorRgb(255, 128, 64));
    });
  });
}
