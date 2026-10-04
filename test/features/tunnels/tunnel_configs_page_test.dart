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
    ),
  ];

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

  Widget page({
    List<TunnelConfigItem> tunnels = const [stoppedTunnel, runningTunnel],
    String? errorMessage,
    VoidCallback? onAdd,
    ValueChanged<TunnelConfigItem>? onStart,
    ValueChanged<TunnelConfigItem>? onStop,
    ValueChanged<TunnelConfigItem>? onEdit,
    ValueChanged<TunnelConfigItem>? onDelete,
    void Function(TunnelConfigItem, TunnelForwardType)? onTypeChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TunnelConfigsPage(
          tunnels: tunnels,
          profiles: profiles,
          errorMessage: errorMessage,
          onAdd: onAdd ?? () {},
          onStart: onStart ?? (_) {},
          onStop: onStop ?? (_) {},
          onEdit: onEdit ?? (_) {},
          onDelete: onDelete ?? (_) {},
          onTypeChanged: onTypeChanged ?? (_, _) {},
        ),
      ),
    );
  }

  testWidgets('renders tunnel rows and wires start stop edit delete', (
    tester,
  ) async {
    TunnelConfigItem? started;
    TunnelConfigItem? stopped;
    TunnelConfigItem? edited;
    TunnelConfigItem? deleted;
    var addTapped = false;

    await tester.pumpWidget(
      page(
        onAdd: () => addTapped = true,
        onStart: (value) => started = value,
        onStop: (value) => stopped = value,
        onEdit: (value) => edited = value,
        onDelete: (value) => deleted = value,
      ),
    );

    expect(find.text('端口转发'), findsOneWidget);
    expect(find.text('Dev API'), findsOneWidget);
    expect(find.text('Webhook'), findsOneWidget);
    expect(find.text('127.0.0.1:18080 → 127.0.0.1:8080'), findsOneWidget);
    expect(find.text('0.0.0.0:19090 → 127.0.0.1:9090'), findsOneWidget);
    // The owning SSH profile is shown under each name.
    expect(find.text('Prod'), findsNWidgets(2));

    await tester.tap(find.text('新增隧道'));
    await tester.pumpAndSettle();
    expect(addTapped, isTrue);

    await tester.tap(find.byKey(const ValueKey('tunnel-start-tunnel-1')));
    await tester.pumpAndSettle();
    expect(started, stoppedTunnel);

    await tester.tap(find.byKey(const ValueKey('tunnel-stop-tunnel-2')));
    await tester.pumpAndSettle();
    expect(stopped, runningTunnel);

    await tester.tap(find.text('编辑').first);
    await tester.pumpAndSettle();
    expect(edited, stoppedTunnel);

    await tester.tap(find.text('删除').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('删除'),
      ),
    );
    await tester.pumpAndSettle();
    expect(deleted, stoppedTunnel);
  });

  testWidgets('reports an inline forward-type change', (tester) async {
    final changes = <(TunnelConfigItem, TunnelForwardType)>[];

    await tester.pumpWidget(
      page(
        tunnels: const [stoppedTunnel],
        onTypeChanged: (tunnel, type) => changes.add((tunnel, type)),
      ),
    );

    // The first row is Local; flip it to Remote.
    await tester.tap(find.text('远程').first);
    await tester.pumpAndSettle();

    expect(changes, [(stoppedTunnel, TunnelForwardType.remote)]);
  });

  testWidgets('shows an empty state with no tunnels', (tester) async {
    await tester.pumpWidget(page(tunnels: const []));

    expect(find.text('还没有隧道'), findsOneWidget);
    expect(find.text('Dev API'), findsNothing);
  });

  testWidgets('surfaces an error without hiding rows', (tester) async {
    await tester.pumpWidget(page(errorMessage: '隧道启动失败'));

    expect(find.text('隧道启动失败'), findsOneWidget);
    expect(find.text('Dev API'), findsOneWidget);
  });
}
