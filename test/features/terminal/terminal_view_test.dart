import 'package:deepssh/features/terminal/terminal_state.dart';
import 'package:deepssh/features/terminal/terminal_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart' as xterm;

void main() {
  testWidgets('renders an xterm terminal for a remote tab', (tester) async {
    const tab = OpenTerminalTab(
      id: 'm1-t1',
      hostId: 'machine1',
      hostName: 'machine1',
      title: 'terminal1',
      sourceType: TerminalSourceType.remote,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(tab: tab),
        ),
      ),
    );

    expect(find.byType(xterm.TerminalView), findsOneWidget);
  });

  testWidgets('renders an xterm terminal for a local tab', (tester) async {
    final tab = OpenTerminalTab.local(
      id: 'local-terminal-1',
      title: 'terminal1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(tab: tab),
        ),
      ),
    );

    expect(find.byType(xterm.TerminalView), findsOneWidget);
    expect(tab.label, 'local · terminal1');
  });
}
