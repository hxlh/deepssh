import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/models/tunnel_config_item.dart';
import 'package:deepssh/features/tunnels/tunnel_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tunnel item formats local and remote forwarding summaries', () {
    const local = TunnelConfigItem(
      id: 'tunnel-1',
      name: 'Dev API',
      type: TunnelForwardType.local,
      sshProfileId: 'profile-1',
      listenHost: '127.0.0.1',
      listenPort: 18080,
      targetHost: '127.0.0.1',
      targetPort: 8080,
      status: TunnelRuntimeStatus.forwarding,
    );
    const remote = TunnelConfigItem(
      id: 'tunnel-2',
      name: 'Webhook',
      type: TunnelForwardType.remote,
      sshProfileId: 'profile-1',
      listenHost: '0.0.0.0',
      listenPort: 19090,
      targetHost: '127.0.0.1',
      targetPort: 9090,
      status: TunnelRuntimeStatus.waiting,
    );

    expect(local.directionLabel, 'LOCAL');
    expect(local.forwardingSummary, 'LOCAL 127.0.0.1:18080 → 127.0.0.1:8080');
    expect(local.isForwarding, isTrue);
    expect(remote.directionLabel, 'REMOTE');
    expect(remote.forwardingSummary, 'REMOTE 0.0.0.0:19090 → 127.0.0.1:9090');
    expect(remote.isForwarding, isFalse);
  });

  test(
    'in-memory tunnel bridge creates updates starts stops and deletes tunnels',
    () async {
      final bridge = InMemoryTunnelBridgeClient();

      final created = await bridge.createTunnel(
        name: 'Dev API',
        type: TunnelForwardType.local,
        sshProfileId: 'profile-1',
        listenHost: '127.0.0.1',
        listenPort: 18080,
        targetHost: '127.0.0.1',
        targetPort: 8080,
      );

      expect(created.id, 'tunnel-1');
      expect(created.status, TunnelRuntimeStatus.stopped);
      expect(await bridge.listTunnels(), [created]);

      final updated = await bridge.updateTunnel(
        id: created.id,
        name: 'Dev API Updated',
        type: TunnelForwardType.remote,
        sshProfileId: 'profile-2',
        listenHost: '0.0.0.0',
        listenPort: 19090,
        targetHost: '127.0.0.1',
        targetPort: 9090,
      );

      expect(updated.name, 'Dev API Updated');
      expect(updated.type, TunnelForwardType.remote);
      expect(updated.status, TunnelRuntimeStatus.stopped);

      final started = await bridge.startTunnel(
        updated.id,
        sshProfile: const SshProfileItem(
          id: 'profile-2',
          name: 'Prod',
          host: 'example.com',
          port: 22,
          username: 'root',
        ),
      );
      expect(started.status, TunnelRuntimeStatus.forwarding);
      expect(
        (await bridge.listTunnels()).single.status,
        TunnelRuntimeStatus.forwarding,
      );

      final stopped = await bridge.stopTunnel(updated.id);
      expect(stopped.status, TunnelRuntimeStatus.stopped);

      await bridge.deleteTunnel(updated.id);
      expect(await bridge.listTunnels(), isEmpty);
    },
  );
}
