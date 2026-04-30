import 'dart:async';

import 'package:deepssh/core/logging/app_logger.dart';
import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/features/local_terminal/local_terminal_bridge.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/theme/theme_bridge.dart';
import 'package:deepssh/features/tunnels/tunnel_bridge.dart';
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('logs theme load failures while keeping the workbench visible', (
    tester,
  ) async {
    final logger = RecordingErrorLogger();

    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchPage(
          sshBridge: FakeSshBridgeClient(),
          themeBridge: FailingThemeBridgeClient(),
          localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
          tunnelBridge: InMemoryTunnelBridgeClient(),
          errorLogger: logger,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WorkbenchPage), findsOneWidget);
    expect(logger.entries.single.scope, 'theme.load');
    expect(
      logger.entries.single.error.toString(),
      contains('theme load failed'),
    );
  });

  testWidgets('logs SSH connect failures while showing the existing UI error', (
    tester,
  ) async {
    final logger = RecordingErrorLogger();

    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchPage(
          sshBridge: FakeSshBridgeClient(
            profiles: [
              SshProfileItem(
                id: 'profile-1',
                name: 'Prod',
                host: 'example.com',
                port: 22,
                username: 'root',
                password: 'secret',
                termType: 'xterm-256color',
              ),
            ],
            connectError: StateError('connect failed'),
          ),
          themeBridge: FakeThemeBridgeClient(),
          localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
          tunnelBridge: InMemoryTunnelBridgeClient(),
          errorLogger: logger,
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

    expect(find.textContaining('Connection failed:'), findsOneWidget);
    expect(logger.entries.single.scope, 'ssh.connect');
    expect(logger.entries.single.error.toString(), contains('connect failed'));
    expect(logger.entries.single.error.toString(), isNot(contains('secret')));
  });
  testWidgets('logs close failures when cleaning up a removed duplicate', (
    tester,
  ) async {
    final logger = RecordingErrorLogger();
    final bridge = FakeSshBridgeClient(
      profiles: [
        SshProfileItem(
          id: 'profile-1',
          name: 'Prod',
          host: 'example.com',
          port: 22,
          username: 'root',
          password: 'secret',
          termType: 'xterm-256color',
        ),
      ],
      closeError: StateError('close duplicate failed'),
    );
    final duplicate = Completer<SshConnectionResult>();
    bridge.duplicateCompleters.add(duplicate);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchPage(
          sshBridge: bridge,
          themeBridge: FakeThemeBridgeClient(),
          localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
          tunnelBridge: InMemoryTunnelBridgeClient(),
          errorLogger: logger,
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

    await tester.tap(find.text('terminal1'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pump();
    await tester.tap(find.text('terminal2'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭 SSH 会话'));
    await tester.pumpAndSettle();

    duplicate.complete(
      const SshConnectionResult(sessionId: 'session-2', title: 'Prod'),
    );
    await tester.pumpAndSettle();

    expect(logger.entries.single.scope, 'ssh.close');
    expect(
      logger.entries.single.error.toString(),
      contains('close duplicate failed'),
    );
  });

  testWidgets(
    'logs close failures when cleaning up a removed pending connect',
    (tester) async {
      final logger = RecordingErrorLogger();
      final bridge = FakeSshBridgeClient(
        profiles: [
          SshProfileItem(
            id: 'profile-1',
            name: 'Prod',
            host: 'example.com',
            port: 22,
            username: 'root',
            password: 'secret',
            termType: 'xterm-256color',
          ),
        ],
        closeError: StateError('close pending failed'),
      );
      final connect = Completer<SshConnectionResult>();
      bridge.connectCompleters.add(connect);

      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchPage(
            sshBridge: bridge,
            themeBridge: FakeThemeBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            tunnelBridge: InMemoryTunnelBridgeClient(),
            errorLogger: logger,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接'));
      await tester.pump();
      await tester.tap(find.text('terminal1'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭 SSH 会话'));
      await tester.pumpAndSettle();

      connect.complete(
        const SshConnectionResult(sessionId: 'session-1', title: 'Prod'),
      );
      await tester.pumpAndSettle();

      expect(logger.entries.single.scope, 'ssh.close');
      expect(
        logger.entries.single.error.toString(),
        contains('close pending failed'),
      );
    },
  );
}

class RecordingErrorLogger implements ErrorLogger {
  final entries = <LoggedError>[];

  @override
  Future<void> error(String scope, Object error, StackTrace? stackTrace) async {
    entries.add(LoggedError(scope, error, stackTrace));
  }
}

class LoggedError {
  LoggedError(this.scope, this.error, this.stackTrace);

  final String scope;
  final Object error;
  final StackTrace? stackTrace;
}

class FakeThemeBridgeClient implements ThemeBridgeClient {
  @override
  Future<({UiThemeSettings ui, TerminalThemeSettings terminal})>
  loadTheme() async {
    return (
      ui: UiThemeSettings.commandDeck(),
      terminal: TerminalThemeSettings.commandDeck(),
    );
  }

  @override
  Future<void> saveTheme({
    required UiThemeSettings ui,
    required TerminalThemeSettings terminal,
  }) async {}
}

class FailingThemeBridgeClient extends FakeThemeBridgeClient {
  @override
  Future<({UiThemeSettings ui, TerminalThemeSettings terminal})>
  loadTheme() async {
    throw StateError('theme load failed');
  }
}

class FakeSshBridgeClient implements SshBridgeClient {
  FakeSshBridgeClient({
    this.profiles = const [],
    this.connectError,
    this.closeError,
  });

  final List<SshProfileItem> profiles;
  final Object? connectError;
  final Object? closeError;
  final connectCompleters = <Completer<SshConnectionResult>>[];
  final duplicateCompleters = <Completer<SshConnectionResult>>[];

  @override
  Future<List<SshProfileItem>> listProfiles() async => profiles;

  @override
  Future<SshProfileItem> createProfile({
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    required String termType,
  }) async {
    return SshProfileItem(
      id: 'created',
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
      termType: termType,
    );
  }

  @override
  Future<SshProfileItem> updateProfile({
    required String id,
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    required String termType,
  }) async {
    return SshProfileItem(
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
      termType: termType,
    );
  }

  @override
  Future<void> deleteProfile(String id) async {}

  @override
  Future<SshConnectionResult> connectProfile(
    String id, {
    int? rows,
    int? cols,
  }) async {
    final error = connectError;
    if (error != null) {
      throw error;
    }
    if (connectCompleters.isNotEmpty) {
      return connectCompleters.removeAt(0).future;
    }
    return SshConnectionResult(sessionId: 'session-1', title: 'Prod');
  }

  @override
  Stream<List<int>> outputStream(String sessionId) => const Stream.empty();

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
    final error = closeError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<SshConnectionResult> duplicateSession(String sessionId) async {
    if (duplicateCompleters.isNotEmpty) {
      return duplicateCompleters.removeAt(0).future;
    }
    return SshConnectionResult(sessionId: 'session-2', title: 'Prod');
  }
}
