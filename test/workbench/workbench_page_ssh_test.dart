import 'dart:async';
import 'dart:convert';

import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/ssh/ssh_zmodem_session.dart';
import 'package:deepssh/features/terminal/terminal_view.dart' as app_terminal;
import 'package:deepssh/src/rust/ssh_auth.dart' as rust_auth;
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart' as xterm;

class FakeSshBridgeClient implements SshBridgeClient {
  final profiles = <SshProfileItem>[];
  final connectCompleters = <Completer<SshConnectionResult>>[];
  var connectCount = 0;
  final connectSizes = <({int rows, int cols})>[];
  var outputStreamListenCount = 0;
  var writeToSessionCount = 0;
  var closeSessionCount = 0;
  String? lastRuntimePassword;
  String? lastRuntimePassphrase;
  Object? connectError;
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
    required SshAuthMode authMode,
    required String password,
    required String privateKeyPath,
    required String termType,
  }) async {
    final profile = SshProfileItem(
      id: 'profile-${profiles.length + 1}',
      name: name,
      host: host,
      port: port,
      username: username,
      authMode: authMode,
      password: password,
      privateKeyPath: privateKeyPath,
      termType: termType,
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
    required SshAuthMode authMode,
    required String password,
    required String privateKeyPath,
    required String termType,
  }) async {
    final index = profiles.indexWhere((profile) => profile.id == id);
    final updated = SshProfileItem(
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      authMode: authMode,
      password: password,
      privateKeyPath: privateKeyPath,
      termType: termType,
    );
    profiles[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteProfile(String id) async {
    profiles.removeWhere((profile) => profile.id == id);
  }

  @override
  Future<SshConnectionResult> connectProfile(
    String id, {
    String? password,
    String? passphrase,
    int? rows,
    int? cols,
  }) async {
    connectCount += 1;
    lastRuntimePassword = password;
    lastRuntimePassphrase = passphrase;
    final error = connectError;
    if (error != null) {
      connectError = null;
      throw error;
    }
    if (rows != null && cols != null) {
      connectSizes.add((rows: rows, cols: cols));
    }
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

class FakeSshZModemBinding implements SshZModemBinding {
  FakeSshZModemBinding({required this.sessionId, required this.stdout});

  final String sessionId;
  final Stream<List<int>> stdout;
  final inputs = <String>[];
  var disposed = false;

  @override
  void writeTerminalInput(String data) {
    inputs.add(data);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
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

  testWidgets('connect with empty saved password prompts for password', (
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
        password: '',
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

    expect(find.text('SSH Password'), findsOneWidget);
    await tester.enterText(find.bySemanticsLabel('Password'), 'typed-secret');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(bridge.lastRuntimePassword, 'typed-secret');
  });

  testWidgets('private key passphrase required retries after prompt', (
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
        authMode: SshAuthMode.privateKey,
        privateKeyPath: '/home/root/.ssh/id_ed25519',
      ),
    );
    bridge.connectError = const SshConnectException(
      rust_auth.SshConnectErrorCode.passphraseRequired,
      'Private key requires a passphrase',
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

    expect(find.text('Private Key Passphrase'), findsOneWidget);
    await tester.enterText(
      find.bySemanticsLabel('Passphrase'),
      'key-passphrase',
    );
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(bridge.connectCount, 2);
    expect(bridge.lastRuntimePassphrase, 'key-passphrase');
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
      expect(find.text('terminal1'), findsWidgets);
      expect(bridge.outputStreamListenCount, 0);

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接'));
      await tester.pump();

      expect(bridge.connectCount, 2);
      expect(find.text('terminal1'), findsWidgets);
      expect(find.text('terminal2'), findsWidgets);

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

  testWidgets('connect passes the rendered terminal size to SSH', (
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

    final terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    expect(bridge.connectSizes, hasLength(1));
    expect(bridge.connectSizes.single.cols, terminalWidget.terminal.viewWidth);
    expect(bridge.connectSizes.single.rows, terminalWidget.terminal.viewHeight);
  });

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

    expect(find.text('terminal1'), findsWidgets);
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(bridge.closeSessionCount, 0);
    expect(find.text('terminal1'), findsOneWidget);

    await tester.tap(find.text('terminal1').first);
    await tester.pumpAndSettle();

    expect(find.text('terminal1'), findsWidgets);
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

      expect(find.text('terminal1'), findsWidgets);

      await tester.tap(
        find.text('terminal1').first,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('关闭 SSH 会话'));
      await tester.pumpAndSettle();

      expect(bridge.closeSessionCount, 1);
      expect(bridge.closedSessionIds, ['session-1']);
      expect(find.text('terminal1'), findsNothing);
    },
  );

  testWidgets(
    'SSH session label prefers note then preview then title',
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

      final terminalWidget = tester.widget<app_terminal.TerminalView>(
        find.byType(app_terminal.TerminalView),
      );
      terminalWidget.tab.terminal!.write('npm run dev');
      await tester.pump();

      expect(find.text('npm run dev'), findsWidgets);
      expect(find.text('terminal1'), findsNothing);

      await tester.tap(find.text('npm run dev').first, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑备注'));
      await tester.pumpAndSettle();

      await tester.enterText(find.bySemanticsLabel('会话备注'), '生产发布');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('生产发布'), findsWidgets);
      expect(find.text('npm run dev'), findsNothing);

      await tester.tap(find.text('生产发布').first, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑备注'));
      await tester.pumpAndSettle();

      await tester.enterText(find.bySemanticsLabel('会话备注'), '');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('npm run dev'), findsWidgets);
      expect(find.text('生产发布'), findsNothing);
      expect(find.text('terminal1'), findsNothing);
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

      expect(find.text('terminal1'), findsWidgets);

      await tester.tap(find.text('terminal1').first, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑备注'));
      await tester.pumpAndSettle();

      await tester.enterText(find.bySemanticsLabel('会话备注'), '生产发布');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('生产发布'), findsWidgets);
      expect(find.text('terminal1'), findsNothing);

      connect.complete(
        const SshConnectionResult(sessionId: 'session-1', title: 'Prod'),
      );
      await tester.pumpAndSettle();

      expect(bridge.outputStreamListenCount, 1);
      expect(find.text('生产发布'), findsWidgets);
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

      expect(find.text('terminal1'), findsWidgets);

      await tester.tap(find.text('terminal1').first, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭 SSH 会话'));
      await tester.pumpAndSettle();

      expect(bridge.closeSessionCount, 0);
      expect(find.text('terminal1'), findsNothing);

      connect.complete(
        const SshConnectionResult(sessionId: 'session-1', title: 'Prod'),
      );
      await tester.pumpAndSettle();

      expect(bridge.closeSessionCount, 1);
      expect(bridge.closedSessionIds, ['session-1']);
      expect(bridge.outputStreamListenCount, 0);
      expect(find.text('terminal1'), findsNothing);
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

    await tester.tap(find.text('terminal1').first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭 SSH 会话'));
    await tester.pumpAndSettle();

    expect(bridge.closeSessionCount, 1);
    expect(find.text('terminal1'), findsWidgets);
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

    await tester.tap(find.text('terminal1').first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭 SSH 会话'));
    await tester.pumpAndSettle();

    expect(bridge.closeSessionCount, 1);
    expect(find.text('terminal1'), findsNothing);
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
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('xterm-truecolor').last);
      await tester.pumpAndSettle();
      final createButton = find.widgetWithText(ElevatedButton, 'Create');
      await tester.scrollUntilVisible(
        createButton,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(bridge.profiles.single.termType, 'xterm-truecolor');

      expect(find.text('Prod'), findsWidgets);
      expect(find.text('root@example.com:2222'), findsOneWidget);

      await tester.tap(find.text('连接'));
      await tester.pumpAndSettle();

      expect(bridge.connectCount, 1);
      expect(find.text('terminal1'), findsWidgets);
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

  testWidgets('SSH session preview updates explorer row and tab title', (
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

    bridge.outputControllers['session-1']!.add(
      r'ubuntu@example:~/src$ npm run dev'.codeUnits,
    );
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text(r'ubuntu@example:~/src$ npm run dev'), findsWidgets);
    expect(find.text('terminal1'), findsNothing);
    expect(find.text('example.com · terminal1'), findsNothing);
  });

  testWidgets('SSH note still overrides captured preview label', (tester) async {
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

    final terminalWidget = tester.widget<app_terminal.TerminalView>(
      find.byType(app_terminal.TerminalView),
    );
    terminalWidget.tab.terminal!.write('npm run dev');
    await tester.pump();

    await tester.tap(find.text('npm run dev').first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('会话备注'), '生产发布');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('生产发布'), findsWidgets);
    expect(find.text('npm run dev'), findsNothing);
  });

  testWidgets('clearing SSH note falls back to stored preview before title', (
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

    final terminalWidget = tester.widget<app_terminal.TerminalView>(
      find.byType(app_terminal.TerminalView),
    );
    terminalWidget.tab.terminal!.write('npm run dev');
    await tester.pump();

    await tester.tap(find.text('npm run dev').first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('会话备注'), '生产发布');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('生产发布').first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('会话备注'), '');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('npm run dev'), findsWidgets);
    expect(find.text('terminal1'), findsNothing);
  });

  testWidgets('remote terminal input uses injected SSH input writer', (
    tester,
  ) async {
    final writes = <({String sessionId, String data})>[];
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
      MaterialApp(
        home: WorkbenchPage(
          sshBridge: bridge,
          debugSshInputWriter: (sessionId, data) {
            writes.add((sessionId: sessionId, data: data));
          },
        ),
      ),
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
    terminalWidget.tab.terminal!.onOutput?.call('ls\r');

    expect(writes, [(sessionId: 'session-1', data: 'ls\r')]);
    expect(bridge.writeToSessionCount, 0);
  });

  testWidgets('workbench creates zmodem binding for connected SSH session', (
    tester,
  ) async {
    final bindings = <FakeSshZModemBinding>[];
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
      MaterialApp(
        home: WorkbenchPage(
          sshBridge: bridge,
          debugSshZModemFactory:
              ({
                required sessionId,
                required stdout,
                required writeTerminal,
                required onDone,
              }) {
                final binding = FakeSshZModemBinding(
                  sessionId: sessionId,
                  stdout: stdout,
                );
                bindings.add(binding);
                stdout.listen((chunk) {
                  writeTerminal(String.fromCharCodes(chunk));
                }, onDone: onDone);
                return binding;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();

    expect(bindings.single.sessionId, 'session-1');

    bridge.outputControllers['session-1']!.add('hello from ssh\r\n'.codeUnits);
    await tester.pump(const Duration(milliseconds: 20));

    final terminalWidget = tester.widget<app_terminal.TerminalView>(
      find.byType(app_terminal.TerminalView),
    );
    expect(
      terminalWidget.tab.terminal!.buffer.toString(),
      contains('hello from ssh'),
    );

    terminalWidget.tab.terminal!.onOutput?.call('pwd\r');
    expect(bindings.single.inputs, ['pwd\r']);
  });
}
