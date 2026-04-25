import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('windows runner enforces 480p minimum window size', () {
    final source = File('windows/runner/win32_window.cpp').readAsStringSync();

    expect(source, contains('kMinWindowWidth = 854'));
    expect(source, contains('kMinWindowHeight = 480'));
    expect(source, contains('WM_GETMINMAXINFO'));
    expect(source, contains('ptMinTrackSize'));
  });
}
