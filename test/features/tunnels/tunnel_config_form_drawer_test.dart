import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/models/tunnel_config_item.dart';
import 'package:deepssh/features/tunnels/tunnel_config_form_drawer.dart';
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

  testWidgets('validates required tunnel fields', (tester) async {
    TunnelConfigDraft? savedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TunnelConfigFormDrawer(
            profiles: profiles,
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await tester.enterText(find.bySemanticsLabel('名称'), '');
    await tester.enterText(find.bySemanticsLabel('监听端口'), '');
    await tester.enterText(find.bySemanticsLabel('目标端口'), '');
    await tester.ensureVisible(find.text('创建'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(find.text('必填'), findsWidgets);
    expect(savedDraft, isNull);
  });

  testWidgets('saves local tunnel draft with selected SSH profile', (
    tester,
  ) async {
    TunnelConfigDraft? savedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TunnelConfigFormDrawer(
            profiles: profiles,
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await tester.enterText(find.bySemanticsLabel('名称'), 'Dev API');
    await tester.enterText(find.bySemanticsLabel('监听主机'), '127.0.0.1');
    await tester.enterText(find.bySemanticsLabel('监听端口'), '18080');
    await tester.enterText(find.bySemanticsLabel('目标主机'), '127.0.0.1');
    await tester.enterText(find.bySemanticsLabel('目标端口'), '8080');
    await tester.ensureVisible(find.text('创建'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(savedDraft?.name, 'Dev API');
    expect(savedDraft?.type, TunnelForwardType.local);
    expect(savedDraft?.sshProfileId, 'profile-1');
    expect(savedDraft?.listenHost, '127.0.0.1');
    expect(savedDraft?.listenPort, 18080);
    expect(savedDraft?.targetHost, '127.0.0.1');
    expect(savedDraft?.targetPort, 8080);
  });

  testWidgets('saves an empty listen port as auto-assign', (tester) async {
    TunnelConfigDraft? savedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TunnelConfigFormDrawer(
            profiles: profiles,
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await tester.enterText(find.bySemanticsLabel('名称'), 'Dev API');
    await tester.enterText(find.bySemanticsLabel('监听端口'), '');
    await tester.enterText(find.bySemanticsLabel('目标主机'), '127.0.0.1');
    await tester.enterText(find.bySemanticsLabel('目标端口'), '8080');
    await tester.ensureVisible(find.text('创建'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(savedDraft?.listenPort, 0);
    expect(savedDraft?.targetPort, 8080);
  });

  testWidgets(
    'edit tunnel form pre-fills current values and saves remote type',
    (tester) async {
      TunnelConfigDraft? savedDraft;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TunnelConfigFormDrawer(
              profiles: profiles,
              tunnel: const TunnelConfigItem(
                id: 'tunnel-1',
                name: 'Webhook',
                type: TunnelForwardType.remote,
                sshProfileId: 'profile-1',
                listenHost: '0.0.0.0',
                listenPort: 19090,
                targetHost: '127.0.0.1',
                targetPort: 9090,
              ),
              onCancel: () {},
              onSaved: (draft) => savedDraft = draft,
            ),
          ),
        ),
      );

      expect(find.text('编辑端口转发'), findsOneWidget);
      expect(find.text('远程转发（-R）'), findsOneWidget);
      await tester.ensureVisible(find.text('保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(savedDraft?.type, TunnelForwardType.remote);
      expect(savedDraft?.listenHost, '0.0.0.0');
      expect(savedDraft?.listenPort, 19090);
    },
  );
}
