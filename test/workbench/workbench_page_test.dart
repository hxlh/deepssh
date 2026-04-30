import 'package:deepssh/features/local_terminal/local_terminal_bridge.dart';
import 'package:deepssh/features/theme/theme_bridge.dart';
import 'package:deepssh/features/tunnels/tunnel_bridge.dart';
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _workbenchApp() {
  return MaterialApp(
    home: WorkbenchPage(
      localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
      tunnelBridge: InMemoryTunnelBridgeClient(),
      themeBridge: InMemoryThemeBridgeClient(),
    ),
  );
}

void main() {
  testWidgets('starts without prototype hosts in the explorer', (tester) async {
    await tester.pumpWidget(_workbenchApp());
    await tester.pumpAndSettle();

    expect(find.text('machine1'), findsNothing);
    expect(find.text('machine2'), findsNothing);
    expect(find.text('terminal1'), findsNothing);
    expect(find.text('Open a terminal from the sidebar'), findsOneWidget);
  });

  testWidgets('closes the active local tab and returns to empty state', (
    tester,
  ) async {
    await tester.pumpWidget(_workbenchApp());

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本地终端'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close local · terminal1'));
    await tester.pumpAndSettle();

    expect(find.text('Open a terminal from the sidebar'), findsOneWidget);
  });
}
