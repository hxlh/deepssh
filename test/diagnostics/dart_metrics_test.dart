import 'package:flutter_test/flutter_test.dart';

import 'package:deepssh/features/diagnostics/dart_metrics.dart';

void main() {
  test('collectDartMetrics returns plausible RSS values', () {
    final snapshot = collectDartMetrics();

    expect(snapshot.processCurrentRss, greaterThan(0));
    expect(snapshot.processMaxRss, greaterThanOrEqualTo(snapshot.processCurrentRss));
  });

  test('DartMemSnapshot.zero exposes neutral values for the UI', () {
    const zero = DartMemSnapshot.zero();

    expect(zero.processCurrentRss, 0);
    expect(zero.processMaxRss, 0);
  });
}
