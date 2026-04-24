import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens and switches terminal tabs from the sidebar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WorkbenchPage()));

    await tester.tap(find.text('terminal1').first);
    await tester.pumpAndSettle();

    expect(find.text('machine1 · terminal1'), findsOneWidget);

    await tester.tap(find.text('terminal2'));
    await tester.pumpAndSettle();

    expect(find.text('machine1 · terminal2'), findsOneWidget);
    expect(find.text('Open a terminal from the sidebar'), findsNothing);
  });

  testWidgets('closes the active tab and returns to empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WorkbenchPage()));

    await tester.tap(find.text('terminal1').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close machine1 · terminal1'));
    await tester.pumpAndSettle();

    expect(find.text('Open a terminal from the sidebar'), findsOneWidget);
  });
}
