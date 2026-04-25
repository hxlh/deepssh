import 'dart:async';
import 'dart:convert';

import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
