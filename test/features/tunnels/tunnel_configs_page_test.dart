import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/models/tunnel_config_item.dart';
import 'package:deepssh/features/tunnels/tunnel_configs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profiles = [
    SshProfileItem(
      id: 'profile-1',
      name: 'Prod',
      host: 'example.com',
      port: 22,
      username: 'root',
      password: 'secret',
    ),
  ];

  testWidgets(
    'renders saved tunnel rows with far-right status dots and actions',
    (tester) async {
      TunnelConfigItem? started;
      TunnelConfigItem? stopped;
      TunnelConfigItem? edited;
      TunnelConfigItem? deleted;
      var addTapped = false;

      const stoppedTunnel = TunnelConfigItem(
        id: 'tunnel-1',
        name: 'Dev API',
        type: TunnelForwardType.local,
        sshProfileId: 'profile-1',
        listenHost: '127.0.0.1',
        listenPort: 18080,
        targetHost: '127.0.0.1',
        targetPort: 8080,
        status: TunnelRuntimeStatus.stopped,
      );
      const runningTunnel = TunnelConfigItem(
        id: 'tunnel-2',
        name: 'Webhook',
        type: TunnelForwardType.remote,
        sshProfileId: 'profile-1',
        listenHost: '0.0.0.0',
        listenPort: 19090,
        targetHost: '127.0.0.1',
        targetPort: 9090,
        status: TunnelRuntimeStatus.forwarding,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TunnelConfigsPage(
              tunnels: const [stoppedTunnel, runningTunnel],
              profiles: profiles,
              errorMessage: null,
              onAdd: () => addTapped = true,
              onStart: (tunnel) => started = tunnel,
              onStop: (tunnel) => stopped = tunnel,
              onEdit: (tunnel) => edited = tunnel,
              onDelete: (tunnel) => deleted = tunnel,
            ),
          ),
        ),
      );

      expect(find.text('Tunnel Connections'), findsOneWidget);
      expect(find.text('Dev API'), findsOneWidget);
      expect(find.text('Webhook'), findsOneWidget);
      expect(
        find.text('LOCAL 127.0.0.1:18080 → 127.0.0.1:8080 via Prod'),
        findsOneWidget,
      );
      expect(
        find.text('REMOTE 0.0.0.0:19090 → 127.0.0.1:9090 via Prod'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('tunnel-status-dot-tunnel-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('tunnel-status-dot-tunnel-2')),
        findsOneWidget,
      );

      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();
      expect(addTapped, isTrue);

      await tester.tap(find.byKey(const Key('tunnel-start-tunnel-1')));
      await tester.pumpAndSettle();
      expect(started, stoppedTunnel);

      await tester.tap(find.byKey(const Key('tunnel-stop-tunnel-2')));
      await tester.pumpAndSettle();
      expect(stopped, runningTunnel);

      await tester.tap(find.byKey(const Key('tunnel-edit-tunnel-1')));
      await tester.pumpAndSettle();
      expect(edited, stoppedTunnel);

      await tester.tap(find.byKey(const Key('tunnel-delete-tunnel-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleted, stoppedTunnel);
    },
  );
}
