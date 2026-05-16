import 'package:deepssh/features/terminal/terminal_state.dart';
import 'package:deepssh/workbench/widgets/tab_strip.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OpenTerminalTab _tab(String id, {String? displayLabel}) => OpenTerminalTab.local(
  id: id,
  title: id,
  displayLabel: displayLabel,
);

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
}
