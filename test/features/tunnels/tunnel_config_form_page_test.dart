import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/models/tunnel_config_item.dart';
import 'package:deepssh/features/tunnels/tunnel_config_form_page.dart';
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
          body: TunnelConfigFormPage(
            profiles: profiles,
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await tester.enterText(find.bySemanticsLabel('Name'), '');
    await tester.enterText(find.bySemanticsLabel('Listen Port'), '');
    await tester.enterText(find.bySemanticsLabel('Target Port'), '');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsWidgets);
    expect(savedDraft, isNull);
  });

  testWidgets('saves local tunnel draft with selected SSH profile', (
    tester,
  ) async {
    TunnelConfigDraft? savedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TunnelConfigFormPage(
            profiles: profiles,
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await tester.enterText(find.bySemanticsLabel('Name'), 'Dev API');
    await tester.enterText(find.bySemanticsLabel('Listen Host'), '127.0.0.1');
    await tester.enterText(find.bySemanticsLabel('Listen Port'), '18080');
    await tester.enterText(find.bySemanticsLabel('Target Host'), '127.0.0.1');
    await tester.enterText(find.bySemanticsLabel('Target Port'), '8080');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(savedDraft?.name, 'Dev API');
    expect(savedDraft?.type, TunnelForwardType.local);
    expect(savedDraft?.sshProfileId, 'profile-1');
    expect(savedDraft?.listenHost, '127.0.0.1');
    expect(savedDraft?.listenPort, 18080);
    expect(savedDraft?.targetHost, '127.0.0.1');
    expect(savedDraft?.targetPort, 8080);
  });

  testWidgets(
    'edit tunnel form pre-fills current values and saves remote type',
    (tester) async {
      TunnelConfigDraft? savedDraft;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TunnelConfigFormPage(
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

      expect(find.text('Edit Tunnel Connection'), findsOneWidget);
      expect(find.text('Remote Forward'), findsOneWidget);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(savedDraft?.type, TunnelForwardType.remote);
      expect(savedDraft?.listenHost, '0.0.0.0');
      expect(savedDraft?.listenPort, 19090);
    },
  );
}
