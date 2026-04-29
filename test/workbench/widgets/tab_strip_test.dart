import 'package:deepssh/features/terminal/terminal_state.dart';
import 'package:deepssh/workbench/widgets/tab_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OpenTerminalTab _tab(String id) =>
    OpenTerminalTab.local(id: id, title: id);

void main() {
  testWidgets('TabStrip renders tabs', (tester) async {
    final tabs = [_tab('a'), _tab('b'), _tab('c')];
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

    expect(find.text('local · a'), findsOneWidget);
    expect(find.text('local · b'), findsOneWidget);
    expect(find.text('local · c'), findsOneWidget);
  });
}
