import 'dart:async';

import 'package:deepssh/features/local_terminal/local_terminal_bridge.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/theme/theme_bridge.dart';
import 'package:deepssh/features/tunnels/tunnel_bridge.dart';
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLocalTerminalBridge implements LocalTerminalBridgeClient {
  FakeLocalTerminalBridge({this.spawnError});

  final Object? spawnError;
  final spawnCompleter = Completer<LocalTerminalConnectionResult>();
  final closedSessionIds = <String>[];
  var spawnCalls = 0;

  @override
  Future<LocalTerminalConnectionResult> spawnLocalTerminal({
    int? rows,
    int? cols,
  }) async {
    spawnCalls++;
    if (spawnError != null) {
      throw spawnError!;
    }
    return spawnCompleter.future;
  }

  @override
  Stream<List<int>> outputStream(String sessionId) {
    return Stream<List<int>>.value(const <int>[]);
  }

  @override
  Future<void> writeToSession(String sessionId, List<int> data) async {}

  @override
  Future<void> resizeSession({
    required String sessionId,
    required int rows,
    required int cols,
  }) async {}

  @override
  Future<void> closeSession(String sessionId) async {
    closedSessionIds.add(sessionId);
  }
}

Future<void> pumpWorkbench(
  WidgetTester tester,
  FakeLocalTerminalBridge localBridge,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WorkbenchPage(
        sshBridge: InMemorySshBridgeClient(),
        localTerminalBridge: localBridge,
        tunnelBridge: InMemoryTunnelBridgeClient(),
        themeBridge: InMemoryThemeBridgeClient(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> createLocalTerminal(WidgetTester tester) async {
  await tester.tap(find.text('新增连接'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('本地终端'));
  await tester.pump();
}

void main() {
  testWidgets('creating local terminal adds row and tab immediately', (
    tester,
  ) async {
    final bridge = FakeLocalTerminalBridge();
    await pumpWorkbench(tester, bridge);

    await createLocalTerminal(tester);

    expect(find.text('terminal1'), findsWidgets);
    expect(bridge.spawnCalls, 1);
  });

  testWidgets('spawn success keeps local terminal row open', (tester) async {
    final bridge = FakeLocalTerminalBridge();
    await pumpWorkbench(tester, bridge);

    await createLocalTerminal(tester);
    bridge.spawnCompleter.complete(
      const LocalTerminalConnectionResult(
        sessionId: 'local-session-1',
        title: 'terminal',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('terminal1'), findsWidgets);
    expect(bridge.closedSessionIds, isEmpty);
  });

  testWidgets('spawn failure removes pending local terminal and shows error', (
    tester,
  ) async {
    final bridge = FakeLocalTerminalBridge(spawnError: StateError('boom'));
    await pumpWorkbench(tester, bridge);

    await createLocalTerminal(tester);
    await tester.pumpAndSettle();

    expect(find.text('terminal1'), findsNothing);
    expect(find.textContaining('Local terminal failed'), findsOneWidget);
  });

  testWidgets('closing local terminal tab closes backend session', (
    tester,
  ) async {
    final bridge = FakeLocalTerminalBridge();
    await pumpWorkbench(tester, bridge);

    await createLocalTerminal(tester);
    bridge.spawnCompleter.complete(
      const LocalTerminalConnectionResult(
        sessionId: 'local-session-1',
        title: 'terminal',
      ),
    );
    await tester.pumpAndSettle();

    final closeButton = find.byIcon(Icons.close).first;
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(bridge.closedSessionIds, contains('local-session-1'));
    expect(find.text('terminal1'), findsNothing);
  });
}
