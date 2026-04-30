import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/models/tunnel_config_item.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/tunnels/tunnel_bridge.dart';
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSshBridgeClient implements SshBridgeClient {
  final profiles = <SshProfileItem>[
    const SshProfileItem(
      id: 'profile-1',
      name: 'Prod',
      host: 'example.com',
      port: 22,
      username: 'root',
      password: 'secret',
    ),
  ];

  @override
  Future<List<SshProfileItem>> listProfiles() async => List.of(profiles);

  @override
  Future<SshProfileItem> createProfile({
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    required String termType,
  }) async => throw UnimplementedError();

  @override
  Future<SshProfileItem> updateProfile({
    required String id,
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    required String termType,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteProfile(String id) async {}

  @override
  Future<SshConnectionResult> connectProfile(
    String id, {
    int? rows,
    int? cols,
  }) async => throw UnimplementedError();

  @override
  Stream<List<int>> outputStream(String sessionId) => Stream.value(const []);

  @override
  Future<void> writeToSession(String sessionId, List<int> data) async {}

  @override
  Future<void> resizeSession({
    required String sessionId,
    required int rows,
    required int cols,
  }) async {}

  @override
  Future<void> closeSession(String sessionId) async {}

  @override
  Future<SshConnectionResult> duplicateSession(String sessionId) async =>
      throw UnimplementedError();
}

class FakeTunnelBridgeClient extends InMemoryTunnelBridgeClient {
  var listCount = 0;
  var startCount = 0;
  var stopCount = 0;

  @override
  Future<List<TunnelConfigItem>> listTunnels() async {
    listCount += 1;
    return super.listTunnels();
  }

  @override
  Future<TunnelConfigItem> startTunnel(String id) async {
    startCount += 1;
    return super.startTunnel(id);
  }

  @override
  Future<TunnelConfigItem> stopTunnel(String id) async {
    stopCount += 1;
    return super.stopTunnel(id);
  }
}

void main() {
  testWidgets(
    'creates tunnel from workbench form and keeps explorer unchanged',
    (tester) async {
      final sshBridge = FakeSshBridgeClient();
      final tunnelBridge = FakeTunnelBridgeClient();

      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchPage(sshBridge: sshBridge, tunnelBridge: tunnelBridge),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新增连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('隧道连接'));
      await tester.pumpAndSettle();

      expect(find.text('Tunnel Connections'), findsOneWidget);
      expect(find.text('Prod'), findsOneWidget);
      expect(find.text('Dev API'), findsNothing);

      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();
      await tester.enterText(find.bySemanticsLabel('Name'), 'Dev API');
      await tester.enterText(find.bySemanticsLabel('Listen Host'), '127.0.0.1');
      await tester.enterText(find.bySemanticsLabel('Listen Port'), '18080');
      await tester.enterText(find.bySemanticsLabel('Target Host'), '127.0.0.1');
      await tester.enterText(find.bySemanticsLabel('Target Port'), '8080');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(tunnelBridge.listCount, greaterThan(0));
      expect(find.text('Dev API'), findsOneWidget);
      expect(
        find.text('LOCAL 127.0.0.1:18080 → 127.0.0.1:8080 via Prod'),
        findsOneWidget,
      );
      expect(find.text('SSH PROFILES'), findsNothing);
    },
  );

  testWidgets('starts and stops a saved tunnel from the workbench page', (
    tester,
  ) async {
    final sshBridge = FakeSshBridgeClient();
    final tunnelBridge = FakeTunnelBridgeClient();
    await tunnelBridge.createTunnel(
      name: 'Dev API',
      type: TunnelForwardType.local,
      sshProfileId: 'profile-1',
      listenHost: '127.0.0.1',
      listenPort: 18080,
      targetHost: '127.0.0.1',
      targetPort: 8080,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchPage(sshBridge: sshBridge, tunnelBridge: tunnelBridge),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('隧道连接'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tunnel-start-tunnel-1')));
    await tester.pumpAndSettle();
    expect(tunnelBridge.startCount, 1);
    expect(find.byKey(const Key('tunnel-stop-tunnel-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tunnel-stop-tunnel-1')));
    await tester.pumpAndSettle();
    expect(tunnelBridge.stopCount, 1);
    expect(find.byKey(const Key('tunnel-start-tunnel-1')), findsOneWidget);
  });
}
