import 'dart:async';

import 'package:deepssh/features/local_terminal/local_terminal_bridge.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/terminal/terminal_view.dart' as app_terminal;
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
  final outputControllers = <String, StreamController<List<int>>>{};
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
    final controller = outputControllers[sessionId];
    if (controller != null) {
      return controller.stream;
    }
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

  testWidgets('local terminal keeps title until active preview is captured', (
    tester,
  ) async {
    final bridge = FakeLocalTerminalBridge();
    await pumpWorkbench(tester, bridge);

    await createLocalTerminal(tester);

    expect(find.text('terminal1'), findsWidgets);
  });

  testWidgets('local terminal preview updates explorer row and tab title', (
    tester,
  ) async {
    final bridge = FakeLocalTerminalBridge();
    bridge.outputControllers['local-session-1'] = StreamController<List<int>>();
    await pumpWorkbench(tester, bridge);

    await createLocalTerminal(tester);
    bridge.spawnCompleter.complete(
      const LocalTerminalConnectionResult(
        sessionId: 'local-session-1',
        title: 'terminal',
      ),
    );
    await tester.pumpAndSettle();

    bridge.outputControllers['local-session-1']!.add(
      r'PS C:\src> npm run dev'.codeUnits,
    );
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text(r'PS C:\src> npm run dev'), findsWidgets);
    expect(find.text('terminal1'), findsNothing);
  });

  testWidgets('empty active local cursor line keeps last non-empty preview', (
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

    final terminalWidget = tester.widget<app_terminal.TerminalView>(
      find.byType(app_terminal.TerminalView),
    );
    terminalWidget.tab.terminal!.write('ready');
    await tester.pump();
    terminalWidget.tab.terminal!.write('\r\n   ');
    await tester.pump();

    expect(find.text('ready'), findsWidgets);
    expect(find.text('terminal1'), findsNothing);
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

  testWidgets('closing local terminal tab keeps backend session alive', (
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

    expect(bridge.closedSessionIds, isEmpty);
    expect(find.text('terminal1'), findsOneWidget);
  });
}
