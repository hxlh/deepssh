import 'dart:async';
import 'dart:convert';

import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/terminal/terminal_view.dart' as app_terminal;
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart' as xterm;

class FakeSshBridgeClient implements SshBridgeClient {
  final profiles = <SshProfileItem>[];
  final connectCompleters = <Completer<SshConnectionResult>>[];
  var connectCount = 0;
  var outputStreamListenCount = 0;
  var writeToSessionCount = 0;
  var closeSessionCount = 0;
  Object? closeError;
  Object? cancelOutputSubscriptionError;
  final closedSessionIds = <String>[];
  List<int> lastWriteData = const [];
  final outputControllers = <String, StreamController<List<int>>>{};

  @override
  Future<List<SshProfileItem>> listProfiles() async => List.of(profiles);

  @override
  Future<SshProfileItem> createProfile({
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    final profile = SshProfileItem(
      id: 'profile-${profiles.length + 1}',
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
    );
    profiles.add(profile);
    return profile;
  }

  @override
  Future<SshProfileItem> updateProfile({
    required String id,
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    final index = profiles.indexWhere((profile) => profile.id == id);
    final updated = SshProfileItem(
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
    );
    profiles[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteProfile(String id) async {
    profiles.removeWhere((profile) => profile.id == id);
  }

  @override
  Future<SshConnectionResult> connectProfile(String id) async {
    connectCount += 1;
    if (connectCompleters.isNotEmpty) {
      return connectCompleters.removeAt(0).future;
    }
    return SshConnectionResult(
      sessionId: 'session-$connectCount',
      title: 'Prod',
    );
  }

  @override
  Stream<List<int>> outputStream(String sessionId) {
    outputStreamListenCount += 1;
    final cancelError = cancelOutputSubscriptionError;
    if (cancelError != null) {
      final controller = StreamController<List<int>>(
        onCancel: () => throw cancelError,
      );
      controller.add('real ssh output\r\n'.codeUnits);
      return controller.stream;
    }
    final controller = outputControllers[sessionId];
    if (controller != null) {
      return controller.stream;
    }
    return Stream.value('real ssh output\r\n'.codeUnits);
  }

  @override
  Future<void> writeToSession(String sessionId, List<int> data) async {
    writeToSessionCount += 1;
    lastWriteData = data;
  }

  @override
  Future<void> resizeSession({
    required String sessionId,
    required int rows,
    required int cols,
  }) async {}

  @override
  Future<void> closeSession(String sessionId) async {
    closeSessionCount += 1;
    closedSessionIds.add(sessionId);
    final error = closeError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<SshConnectionResult> duplicateSession(String sessionId) async {
    return SshConnectionResult(
      sessionId: 'ssh-session-dup',
      title: 'duplicated',
    );
  }
}

void main() {
  testWidgets(
    'shows SSH profiles in explorer instead of static prototype hosts',
    (tester) async {
      final bridge = FakeSshBridgeClient();
      bridge.profiles.add(
        const SshProfileItem(
          id: 'profile-1',
          name: 'Prod',
          host: 'example.com',
          port: 22,
          username: 'root',
          password: 'secret',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Prod'), findsOneWidget);
      expect(find.text('machine1'), findsNothing);
      expect(find.text('machine2'), findsNothing);
    },
  );

  testWidgets('reloads SSH profiles from bridge when opening SSH page again', (
    tester,
  ) async {
    final bridge = FakeSshBridgeClient();

    await tester.pumpWidget(
      MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
    );

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH'));
    await tester.pumpAndSettle();

    expect(find.text('SSH Configurations'), findsOneWidget);
    expect(find.text('Prod'), findsNothing);

    bridge.profiles.add(
      const SshProfileItem(
        id: 'profile-1',
        name: 'Prod',
        host: 'example.com',
        port: 22,
        username: 'root',
        password: 'secret',
      ),
    );

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH'));
    await tester.pumpAndSettle();

    expect(find.text('Prod'), findsWidgets);
    expect(find.text('root@example.com:22'), findsOneWidget);
  });

  testWidgets('clicking SSH profile in explorer does not start a connection', (
    tester,
  ) async {
    final bridge = FakeSshBridgeClient();
    bridge.profiles.add(
      const SshProfileItem(
        id: 'profile-1',
        name: 'Prod',
        host: 'example.com',
        port: 22,
        username: 'root',
        password: 'secret',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prod'));
    await tester.pump();

    expect(bridge.connectCount, 0);
    expect(find.text('terminal1'), findsNothing);
    expect(find.text('example.com · terminal1'), findsNothing);
  });

  testWidgets(
    'connect button adds SSH sessions immediately and allows repeated connects',
    (tester) async {
      final bridge = FakeSshBridgeClient();
      bridge.profiles.add(
        const SshProfileItem(
          id: 'profile-1',
          name: 'Prod',
          host: 'example.com',
          port: 22,
          username: 'root',
          password: 'secret',
        ),
      );
      final firstConnect = Completer<SshConnectionResult>();
      final secondConnect = Completer<SshConnectionResult>();
      bridge.connectCompleters.add(firstConnect);
      bridge.connectCompleters.add(secondConnect);

      await tester.pumpWidget(
        MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接'));
      await tester.pump();

      expect(bridge.connectCount, 1);
      expect(find.text('example.com · terminal1'), findsOneWidget);
      expect(find.text('terminal1'), findsOneWidget);
      expect(bridge.outputStreamListenCount, 0);

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接'));
      await tester.pump();

      expect(bridge.connectCount, 2);
      expect(find.text('terminal1'), findsOneWidget);
      expect(find.text('terminal2'), findsOneWidget);
      expect(find.text('example.com · terminal2'), findsOneWidget);

      firstConnect.complete(
        const SshConnectionResult(sessionId: 'session-1', title: 'Prod'),
      );
      secondConnect.complete(
        const SshConnectionResult(sessionId: 'session-2', title: 'Prod'),
      );
      await tester.pumpAndSettle();

      expect(bridge.outputStreamListenCount, 2);
    },
  );

  testWidgets('closing an SSH tab keeps the session available in explorer', (
    tester,
  ) async {
    final bridge = FakeSshBridgeClient();
    bridge.profiles.add(
      const SshProfileItem(
        id: 'profile-1',
        name: 'Prod',
        host: 'example.com',
        port: 22,
        username: 'root',
        password: 'secret',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();

    expect(find.text('example.com · terminal1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(bridge.closeSessionCount, 0);
    expect(find.text('terminal1'), findsOneWidget);

    await tester.tap(find.text('terminal1'));
    await tester.pumpAndSettle();

    expect(find.text('example.com · terminal1'), findsOneWidget);
  });

  testWidgets(
    'right-click close permanently closes SSH session from explorer',
    (tester) async {
      final bridge = FakeSshBridgeClient();
      bridge.profiles.add(
        const SshProfileItem(
          id: 'profile-1',
          name: 'Prod',
          host: 'example.com',
          port: 22,
          username: 'root',
          password: 'secret',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接'));
      await tester.pumpAndSettle();

      expect(find.text('terminal1'), findsOneWidget);
      expect(find.text('example.com · terminal1'), findsOneWidget);

      await tester.tap(find.text('terminal1'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('关闭 SSH 会话'));
      await tester.pumpAndSettle();

      expect(bridge.closeSessionCount, 1);
      expect(bridge.closedSessionIds, ['session-1']);
      expect(find.text('terminal1'), findsNothing);
      expect(find.text('example.com · terminal1'), findsNothing);
    },
  );

  testWidgets(
    'SSH session label prefers note then current command then title',
    (tester) async {
      final bridge = FakeSshBridgeClient();
      bridge.profiles.add(
        const SshProfileItem(
          id: 'profile-1',
          name: 'Prod',
          host: 'example.com',
          port: 22,
          username: 'root',
          password: 'secret',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接'));
      await tester.pumpAndSettle();

      expect(find.text('terminal1'), findsOneWidget);

      await tester.tap(find.text('terminal1'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑备注'));
      await tester.pumpAndSettle();

      await tester.enterText(find.bySemanticsLabel('会话备注'), '生产发布');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('生产发布'), findsOneWidget);
      expect(find.text('terminal1'), findsNothing);

      await tester.tap(find.text('生产发布'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑备注'));
      await tester.pumpAndSettle();

      await tester.enterText(find.bySemanticsLabel('会话备注'), '');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('terminal1'), findsOneWidget);
      expect(find.text('生产发布'), findsNothing);
    },
  );

  testWidgets(
    'SSH session keeps note edited while connect is pending after connect completes',
    (tester) async {
      final bridge = FakeSshBridgeClient();
      bridge.profiles.add(
        const SshProfileItem(
          id: 'profile-1',
          name: 'Prod',
          host: 'example.com',
          port: 22,
          username: 'root',
          password: 'secret',
        ),
      );
      final connect = Completer<SshConnectionResult>();
      bridge.connectCompleters.add(connect);

      await tester.pumpWidget(
        MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接'));
      await tester.pump();

      expect(find.text('terminal1'), findsOneWidget);

      await tester.tap(find.text('terminal1'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑备注'));
      await tester.pumpAndSettle();

      await tester.enterText(find.bySemanticsLabel('会话备注'), '生产发布');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('生产发布'), findsOneWidget);
      expect(find.text('terminal1'), findsNothing);

      connect.complete(
        const SshConnectionResult(sessionId: 'session-1', title: 'Prod'),
      );
      await tester.pumpAndSettle();

      expect(bridge.outputStreamListenCount, 1);
      expect(find.text('生产发布'), findsOneWidget);
      expect(find.text('terminal1'), findsNothing);
    },
  );

  testWidgets(
    'closing pending SSH session cleans up connection if connect later succeeds',
    (tester) async {
      final bridge = FakeSshBridgeClient();
      bridge.profiles.add(
        const SshProfileItem(
          id: 'profile-1',
          name: 'Prod',
          host: 'example.com',
          port: 22,
          username: 'root',
          password: 'secret',
        ),
      );
      final connect = Completer<SshConnectionResult>();
      bridge.connectCompleters.add(connect);

      await tester.pumpWidget(
        MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接'));
      await tester.pump();

      expect(find.text('terminal1'), findsOneWidget);
      expect(find.text('example.com · terminal1'), findsOneWidget);

      await tester.tap(find.text('terminal1'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭 SSH 会话'));
      await tester.pumpAndSettle();

      expect(bridge.closeSessionCount, 0);
      expect(find.text('terminal1'), findsNothing);
      expect(find.text('example.com · terminal1'), findsNothing);

      connect.complete(
        const SshConnectionResult(sessionId: 'session-1', title: 'Prod'),
      );
      await tester.pumpAndSettle();

      expect(bridge.closeSessionCount, 1);
      expect(bridge.closedSessionIds, ['session-1']);
      expect(bridge.outputStreamListenCount, 0);
      expect(find.text('terminal1'), findsNothing);
      expect(find.text('example.com · terminal1'), findsNothing);
    },
  );

  testWidgets('failed closeSession keeps SSH session in explorer and tab', (
    tester,
  ) async {
    final bridge = FakeSshBridgeClient();
    bridge.closeError = StateError('close failed');
    bridge.profiles.add(
      const SshProfileItem(
        id: 'profile-1',
        name: 'Prod',
        host: 'example.com',
        port: 22,
        username: 'root',
        password: 'secret',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('terminal1'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭 SSH 会话'));
    await tester.pumpAndSettle();

    expect(bridge.closeSessionCount, 1);
    expect(find.text('terminal1'), findsOneWidget);
    expect(find.text('example.com · terminal1'), findsOneWidget);
  });

  testWidgets('cancel output subscription failure still removes SSH UI', (
    tester,
  ) async {
    final bridge = FakeSshBridgeClient();
    bridge.cancelOutputSubscriptionError = StateError('cancel failed');
    bridge.profiles.add(
      const SshProfileItem(
        id: 'profile-1',
        name: 'Prod',
        host: 'example.com',
        port: 22,
        username: 'root',
        password: 'secret',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('terminal1'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭 SSH 会话'));
    await tester.pumpAndSettle();

    expect(bridge.closeSessionCount, 1);
    expect(find.text('terminal1'), findsNothing);
    expect(find.text('example.com · terminal1'), findsNothing);
  });

  testWidgets('batches rapid SSH output before updating terminal state', (
    tester,
  ) async {
    final bridge = FakeSshBridgeClient();
    bridge.profiles.add(
      const SshProfileItem(
        id: 'profile-1',
        name: 'Prod',
        host: 'example.com',
        port: 22,
        username: 'root',
        password: 'secret',
      ),
    );
    bridge.outputControllers['session-1'] = StreamController<List<int>>();

    await tester.pumpWidget(
      MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();

    final controller = bridge.outputControllers['session-1']!;
    controller.add(utf8.encode('line 1\r\n'));
    controller.add(utf8.encode('line 2\r\n'));
    controller.add(utf8.encode('line 3\r\n'));
    await tester.pump();

    var terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    expect(
      terminalWidget.terminal.buffer.toString(),
      isNot(contains('line 3')),
    );

    await tester.pump(const Duration(milliseconds: 40));

    terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    final text = terminalWidget.terminal.buffer.toString();
    expect(text, contains('line 1'));
    expect(text, contains('line 2'));
    expect(text, contains('line 3'));
  });

  testWidgets('does not retain large SSH output in tab history', (
    tester,
  ) async {
    final bridge = FakeSshBridgeClient();
    bridge.profiles.add(
      const SshProfileItem(
        id: 'profile-1',
        name: 'Prod',
        host: 'example.com',
        port: 22,
        username: 'root',
        password: 'secret',
      ),
    );
    bridge.outputControllers['session-1'] = StreamController<List<int>>();

    await tester.pumpWidget(
      MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();

    final largeOutput = '${'tidb'.padRight(2048, 'x')}\r\n';
    bridge.outputControllers['session-1']!.add(utf8.encode(largeOutput));
    await tester.pump(const Duration(milliseconds: 40));

    final terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    expect(terminalWidget.terminal.buffer.toString(), contains('tidb'));

    final appTerminalWidget = tester.widget<app_terminal.TerminalView>(
      find.byType(app_terminal.TerminalView),
    );
    expect(appTerminalWidget.tab.history, isEmpty);
  });

  testWidgets(
    'creates SSH profile from workbench form and opens SSH tab on connect',
    (tester) async {
      final bridge = FakeSshBridgeClient();

      await tester.pumpWidget(
        MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
      );

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSH'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();

      await tester.enterText(find.bySemanticsLabel('Name'), 'Prod');
      await tester.enterText(find.bySemanticsLabel('Host'), 'example.com');
      await tester.enterText(find.bySemanticsLabel('Port'), '2222');
      await tester.enterText(find.bySemanticsLabel('Username'), 'root');
      await tester.enterText(find.bySemanticsLabel('Password'), 'secret');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Prod'), findsWidgets);
      expect(find.text('root@example.com:2222'), findsOneWidget);

      await tester.tap(find.text('连接'));
      await tester.pumpAndSettle();

      expect(bridge.connectCount, 1);
      expect(find.text('example.com · terminal1'), findsOneWidget);
      expect(find.text('SSH Configurations'), findsNothing);

      await tester.pump(const Duration(milliseconds: 250));

      expect(bridge.outputStreamListenCount, 1);

      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      await tester.tap(find.byKey(const Key('terminal-input-proxy')));
      await tester.pump(const Duration(seconds: 1));
      binding.testTextInput.enterText('中文');
      await binding.idle();

      expect(bridge.writeToSessionCount, greaterThan(0));
      expect(utf8.decode(bridge.lastWriteData), '中文');
    },
  );

  testWidgets('SSH session shows last submitted command after Enter', (
    tester,
  ) async {
    final bridge = FakeSshBridgeClient();
    bridge.profiles.add(
      const SshProfileItem(
        id: 'profile-1',
        name: 'Prod',
        host: 'example.com',
        port: 22,
        username: 'root',
        password: 'secret',
      ),
    );
    bridge.outputControllers['session-1'] = StreamController<List<int>>();

    await tester.pumpWidget(
      MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();

    final terminalWidget = tester.widget<app_terminal.TerminalView>(
      find.byType(app_terminal.TerminalView),
    );

    terminalWidget.onSshInput?.call('ls -la');
    await tester.pump();
    expect(find.text('ls -la'), findsNothing);

    terminalWidget.onSshInput?.call('\r');
    await tester.pump();

    expect(find.text('ls -la'), findsOneWidget);
  });

  testWidgets(
    'Ctrl+C clears pending command without replacing displayed command',
    (tester) async {
      final bridge = FakeSshBridgeClient();
      bridge.profiles.add(
        const SshProfileItem(
          id: 'profile-1',
          name: 'Prod',
          host: 'example.com',
          port: 22,
          username: 'root',
          password: 'secret',
        ),
      );
      bridge.outputControllers['session-1'] = StreamController<List<int>>();

      await tester.pumpWidget(
        MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接'));
      await tester.pumpAndSettle();

      final terminalWidget = tester.widget<app_terminal.TerminalView>(
        find.byType(app_terminal.TerminalView),
      );

      terminalWidget.onSshInput?.call('ls -la\r');
      await tester.pump();
      expect(find.text('ls -la'), findsOneWidget);

      terminalWidget.onSshInput?.call('pwd');
      await tester.pump();
      expect(find.text('pwd'), findsNothing);

      terminalWidget.onSshInput?.call('\x03');
      await tester.pump();

      expect(find.text('ls -la'), findsOneWidget);
      expect(find.text('pwd'), findsNothing);
    },
  );

  testWidgets('Backspace removes last character from pending command', (
    tester,
  ) async {
    final bridge = FakeSshBridgeClient();
    bridge.profiles.add(
      const SshProfileItem(
        id: 'profile-1',
        name: 'Prod',
        host: 'example.com',
        port: 22,
        username: 'root',
        password: 'secret',
      ),
    );
    bridge.outputControllers['session-1'] = StreamController<List<int>>();

    await tester.pumpWidget(
      MaterialApp(home: WorkbenchPage(sshBridge: bridge)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();

    final terminalWidget = tester.widget<app_terminal.TerminalView>(
      find.byType(app_terminal.TerminalView),
    );

    terminalWidget.onSshInput?.call('ls -l');
    terminalWidget.onSshInput?.call('\x7F');
    terminalWidget.onSshInput?.call('\r');
    await tester.pump();

    expect(find.text('ls -'), findsOneWidget);
  });
}
