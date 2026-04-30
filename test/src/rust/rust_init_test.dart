import 'package:deepssh/src/rust/rust_init.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared Rust initializer runs init only once across callers', () async {
    var calls = 0;
    final initializer = RustInitializer(() async {
      calls++;
    });

    await Future.wait([
      initializer.ensureInitialized(),
      initializer.ensureInitialized(),
      initializer.ensureInitialized(),
    ]);

    expect(calls, 1);
  });
}
