import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/models/tunnel_config_item.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/tunnels/tunnel_bridge.dart';
import 'package:deepssh/src/rust/ssh_auth.dart' as rust_auth;
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSshBridgeClient implements SshBridgeClient {
  FakeSshBridgeClient({List<SshProfileItem>? profiles})
    : profiles =
          profiles ??
          <SshProfileItem>[
            const SshProfileItem(
              id: 'profile-1',
              name: 'Prod',
              host: 'example.com',
              port: 22,
              username: 'root',
              password: 'secret',
            ),
          ];

  final List<SshProfileItem> profiles;

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
  }) async => throw UnimplementedError();

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
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteProfile(String id) async {}

  @override
  Future<SshConnectionResult> connectProfile(
    String id, {
    String? password,
    String? passphrase,
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
  String? lastRuntimePassword;
  String? lastRuntimePassphrase;
  Object? startError;

  @override
  Future<List<TunnelConfigItem>> listTunnels() async {
    listCount += 1;
    return super.listTunnels();
  }

  @override
  Future<TunnelConfigItem> startTunnel(
    String id, {
    required SshProfileItem sshProfile,
    String? password,
    String? passphrase,
  }) async {
    startCount += 1;
    lastRuntimePassword = password;
    lastRuntimePassphrase = passphrase;
    final error = startError;
    if (error != null) {
      startError = null;
      throw error;
    }
    return super.startTunnel(id, sshProfile: sshProfile);
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

  testWidgets('tunnel start with empty saved password prompts for password', (
    tester,
  ) async {
    final sshBridge = FakeSshBridgeClient(
      profiles: const [
        SshProfileItem(
          id: 'profile-1',
          name: 'Prod',
          host: 'example.com',
          port: 22,
          username: 'root',
          password: '',
        ),
      ],
    );
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
    expect(find.text('SSH Password'), findsOneWidget);

    await tester.enterText(find.bySemanticsLabel('Password'), 'runtime-secret');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(tunnelBridge.startCount, 1);
    expect(tunnelBridge.lastRuntimePassword, 'runtime-secret');
    expect(find.byKey(const Key('tunnel-stop-tunnel-1')), findsOneWidget);
  });

  testWidgets('private key tunnel start retries after passphrase prompt', (
    tester,
  ) async {
    final sshBridge = FakeSshBridgeClient(
      profiles: const [
        SshProfileItem(
          id: 'profile-1',
          name: 'Prod',
          host: 'example.com',
          port: 22,
          username: 'root',
          authMode: SshAuthMode.privateKey,
          privateKeyPath: 'C:/Users/hxlh/.ssh/id_ed25519',
        ),
      ],
    );
    final tunnelBridge = FakeTunnelBridgeClient()
      ..startError = const SshConnectException(
        rust_auth.SshConnectErrorCode.passphraseRequired,
        'Private key requires a passphrase',
      );
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
    expect(find.text('Private Key Passphrase'), findsOneWidget);

    await tester.enterText(find.bySemanticsLabel('Passphrase'), 'key-secret');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(tunnelBridge.startCount, 2);
    expect(tunnelBridge.lastRuntimePassphrase, 'key-secret');
    expect(find.byKey(const Key('tunnel-stop-tunnel-1')), findsOneWidget);
  });
}
