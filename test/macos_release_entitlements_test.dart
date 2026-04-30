import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS release entitlements allow outbound network access', () {
    final source = File('macos/Runner/Release.entitlements').readAsStringSync();

    expect(
      source,
      contains(
        RegExp(
          r'<key>com\.apple\.security\.network\.client</key>\s*<true/>',
        ),
      ),
    );
  });
}
