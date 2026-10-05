import 'package:deepssh/core/widgets/deck_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a toast dismisses itself after the duration', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    final context = tester.element(find.byType(SizedBox));
    showDeckToast(context, '已保存主题');
    await tester.pump();
    expect(find.text('已保存主题'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();
    expect(find.text('已保存主题'), findsNothing);
  });

  testWidgets('a later toast still expires after an earlier one', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    final context = tester.element(find.byType(SizedBox));
    showDeckToast(context, '第一条');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    showDeckToast(context, '第二条');
    await tester.pump();

    // First toast expires at t=2600; the second was pushed at t=1000.
    await tester.pump(const Duration(milliseconds: 1700));
    expect(find.text('第一条'), findsNothing);
    expect(find.text('第二条'), findsOneWidget);

    // Before the fix, the surviving toast kept the first toast's already
    // fired timer and stayed on screen forever.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.text('第二条'), findsNothing);
  });
}
