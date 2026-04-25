import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens SSH profiles page from add connection menu', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WorkbenchPage()));

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH'));
    await tester.pumpAndSettle();

    expect(find.text('SSH Configurations'), findsOneWidget);
    expect(find.text('新增'), findsOneWidget);
  });

  testWidgets('creates local terminals from add connection menu', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WorkbenchPage()));

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本地终端'));
    await tester.pumpAndSettle();

    expect(find.text('Local'), findsOneWidget);
    expect(find.text('terminal1'), findsWidgets);
    expect(find.text('local · terminal1'), findsOneWidget);

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本地终端'));
    await tester.pumpAndSettle();

    expect(find.text('terminal2'), findsWidgets);
    expect(find.text('local · terminal2'), findsOneWidget);
  });

  testWidgets(
    'right-click close removes local terminal from explorer and tabs',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WorkbenchPage()));

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('本地终端'));
      await tester.pumpAndSettle();

      expect(find.text('Local'), findsOneWidget);
      expect(find.text('terminal1'), findsWidgets);
      expect(find.text('local · terminal1'), findsOneWidget);

      await tester.tap(
        find.text('terminal1').first,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('关闭终端'));
      await tester.pumpAndSettle();

      expect(find.text('terminal1'), findsNothing);
      expect(find.text('local · terminal1'), findsNothing);
    },
  );

  testWidgets(
    'returns to terminal mode when local terminal is created from SSH page',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WorkbenchPage()));

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSH'));
      await tester.pumpAndSettle();

      expect(find.text('SSH Configurations'), findsOneWidget);

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('本地终端'));
      await tester.pumpAndSettle();

      expect(find.text('SSH Configurations'), findsNothing);
      expect(find.text('local · terminal1'), findsOneWidget);
    },
  );
}
