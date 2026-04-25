import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts without prototype hosts in the explorer', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WorkbenchPage()));
    await tester.pumpAndSettle();

    expect(find.text('machine1'), findsNothing);
    expect(find.text('machine2'), findsNothing);
    expect(find.text('terminal1'), findsNothing);
    expect(find.text('Open a terminal from the sidebar'), findsOneWidget);
  });

  testWidgets('closes the active local tab and returns to empty state', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WorkbenchPage()));

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本地终端'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close local · terminal1'));
    await tester.pumpAndSettle();

    expect(find.text('Open a terminal from the sidebar'), findsOneWidget);
  });
}
