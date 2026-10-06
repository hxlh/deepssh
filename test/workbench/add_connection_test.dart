import 'package:deepssh/features/local_terminal/local_terminal_bridge.dart';
import 'package:deepssh/features/theme/theme_bridge.dart';
import 'package:deepssh/features/tunnels/tunnel_bridge.dart';
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deepssh/workbench/widgets/add_connection_button.dart';

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
  testWidgets('opens SSH profiles page from add connection menu', (
    tester,
  ) async {
    await tester.pumpWidget(_workbenchApp());

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(addConnectionMenuKey(AddConnectionAction.ssh)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('deck-page-title')), findsOneWidget);
    expect(find.text('新增 SSH 配置'), findsOneWidget);
  });

  testWidgets('creates local terminals from add connection menu', (
    tester,
  ) async {
    await tester.pumpWidget(_workbenchApp());

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(addConnectionMenuKey(AddConnectionAction.localTerminal)));
    await tester.pumpAndSettle();

    expect(find.text('Local'), findsOneWidget);
    expect(find.text('terminal1'), findsWidgets);
    expect(find.text('local · terminal1'), findsNothing);

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(addConnectionMenuKey(AddConnectionAction.localTerminal)));
    await tester.pumpAndSettle();

    expect(find.text('terminal2'), findsWidgets);
    expect(find.text('local · terminal2'), findsNothing);
  });

  testWidgets(
    'right-click close removes local terminal from explorer and tabs',
    (tester) async {
      await tester.pumpWidget(_workbenchApp());

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(addConnectionMenuKey(AddConnectionAction.localTerminal)));
      await tester.pumpAndSettle();

      expect(find.text('Local'), findsOneWidget);
      expect(find.text('terminal1'), findsWidgets);
      expect(find.text('local · terminal1'), findsNothing);

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
      await tester.pumpWidget(_workbenchApp());

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(addConnectionMenuKey(AddConnectionAction.ssh)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('deck-page-title')), findsOneWidget);

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(addConnectionMenuKey(AddConnectionAction.localTerminal)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('deck-page-title')), findsNothing);
      expect(find.text('local · terminal1'), findsNothing);
      expect(find.text('terminal1'), findsWidgets);
    },
  );

  testWidgets('opens tunnel connections page from add connection menu', (
    tester,
  ) async {
    await tester.pumpWidget(_workbenchApp());

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(addConnectionMenuKey(AddConnectionAction.tunnel)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('deck-page-title')), findsOneWidget);
    expect(find.text('新增转发'), findsOneWidget);
  });
}
