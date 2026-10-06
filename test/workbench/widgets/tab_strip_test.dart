import 'package:deepssh/features/terminal/terminal_state.dart';
import 'package:deepssh/workbench/widgets/tab_strip.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OpenTerminalTab _tab(String id, {String? displayLabel}) =>
    OpenTerminalTab.local(id: id, title: id, displayLabel: displayLabel);

void main() {
  testWidgets('TabStrip renders resolved tab labels', (tester) async {
    final tabs = [
      _tab('a', displayLabel: 'npm run dev'),
      _tab('b'),
      _tab('c', displayLabel: 'top'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: TabStrip(
          tabs: tabs,
          activeTabId: 'a',
          onSelect: (_) {},
          onClose: (_) {},
          onReorder: (_, __) {},
        ),
      ),
    );

    expect(find.text('npm run dev'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('top'), findsOneWidget);
    expect(find.text('local · a'), findsNothing);
  });

  testWidgets('tab hugs its label and keeps the close button at the edge', (
    tester,
  ) async {
    const shortLabel = 'top';
    const longLabel = r'PS C:\Users\hxlh';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TabStrip(
                tabs: [
                  _tab('a', displayLabel: shortLabel),
                  _tab('b', displayLabel: longLabel),
                ],
                activeTabId: 'a',
                onSelect: (_) {},
                onClose: (_) {},
                onReorder: (_, __) {},
              ),
            ],
          ),
        ),
      ),
    );

    Rect tabRect(String label) => tester.getRect(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );

    final shortTab = tabRect(shortLabel);
    final longTab = tabRect(longLabel);
    expect(
      shortTab.width,
      lessThan(160),
      reason: 'a short label must not stretch the tab to the maximum width',
    );
    expect(longTab.width, lessThanOrEqualTo(260));
    expect(longTab.width, greaterThan(shortTab.width));

    final closeRect = tester.getRect(find.byTooltip('关闭 $shortLabel'));
    expect(shortTab.right - closeRect.right, closeTo(8, 1));
  });

  testWidgets('scrolls tabs horizontally with normal mouse wheel', (
    tester,
  ) async {
    final tabs = List.generate(12, (index) => _tab('tab-$index'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 440,
            child: TabStrip(
              tabs: tabs,
              activeTabId: 'tab-0',
              onSelect: (_) {},
              onClose: (_) {},
              onReorder: (_, __) {},
            ),
          ),
        ),
      ),
    );

    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
    final scrollableState = tester.state<ScrollableState>(
      find.byType(Scrollable),
    );
    expect(scrollable.axisDirection, AxisDirection.right);
    expect(scrollableState.position.pixels, 0);

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(TabStrip)),
        scrollDelta: const Offset(0, 120),
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pump();

    expect(scrollableState.position.pixels, greaterThan(0));
    expect(find.byType(RawScrollbar), findsNothing);
  });

  testWidgets('right-click closes tabs to the right and settles focus', (
    tester,
  ) async {
    var tabs = [_tab('a'), _tab('b'), _tab('c'), _tab('d')];
    var active = 'c';
    final closed = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TabStrip(
              tabs: tabs,
              activeTabId: active,
              onSelect: (id) => setState(() => active = id),
              onClose: (id) => setState(() {
                closed.add(id);
                tabs = [
                  for (final tab in tabs)
                    if (tab.id != id) tab,
                ];
              }),
              onReorder: (_, __) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('b'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('关闭左侧标签'), findsOneWidget);
    expect(find.text('关闭右侧标签'), findsOneWidget);
    expect(find.text('关闭其他标签'), findsOneWidget);

    await tester.tap(find.text('关闭右侧标签'));
    await tester.pumpAndSettle();

    expect(closed, ['c', 'd']);
    expect(find.text('c'), findsNothing);
    expect(find.text('d'), findsNothing);
    expect(find.text('a'), findsOneWidget);
    // The old active tab was among the closed ones; the clicked tab settles
    // the result, exactly like the prototype's closeTabsAround.
    expect(active, 'b');
    expect(find.text('已关闭 2 个标签'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();
  });

  testWidgets('an empty bulk-close choice explains itself with a toast', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TabStrip(
            tabs: [_tab('only')],
            activeTabId: 'only',
            onSelect: (_) {},
            onClose: (_) {},
            onReorder: (_, __) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('only'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭其他标签'));
    await tester.pumpAndSettle();

    expect(find.text('没有其他标签可关闭'), findsOneWidget);
    expect(find.text('only'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();
  });
}
