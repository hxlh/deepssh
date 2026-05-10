import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deepssh/features/diagnostics/diagnostics_page.dart';

void main() {
  testWidgets('DiagnosticsPage renders all three layer cards and a back button',
      (tester) async {
    var backTapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiagnosticsPage(onBack: () => backTapped++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('内存监控'), findsOneWidget);
    expect(find.text('Rust'), findsOneWidget);
    expect(find.text('Dart'), findsOneWidget);
    expect(find.text('Flutter image cache'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(backTapped, 1);
  });

  testWidgets('Refresh button triggers a snapshot', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiagnosticsPage(
            onBack: () {},
            debugSnapshotProbe: () => refreshes++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initial = refreshes;
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    expect(refreshes, greaterThan(initial));
  });
}
