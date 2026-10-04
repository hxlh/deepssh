// Headless render checks for the deck redesign.
//
// Opt-in review aid, not a pass/fail gate:
//
//   DECK_GOLDENS=1 flutter test test/goldens/deck_golden_test.dart --update-goldens
//
// The goldens are font-dependent — this box has no Georgia, JetBrains Mono or
// CJK sans, so text falls back and only layout, colour and spacing are
// meaningful. That also means the images never match on another machine, which
// is why the test skips itself by default rather than failing CI.
import 'dart:io';

import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/core/models/tunnel_config_item.dart';
import 'package:deepssh/features/ssh_profiles/ssh_profiles_page.dart';
import 'package:deepssh/features/theme_config/theme_config_page.dart';
import 'package:deepssh/features/tunnels/tunnel_configs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


const _profiles = [
  SshProfileItem(id: 'p1', name: 'prod-web-01', host: '10.0.3.17', port: 22, username: 'deploy'),
  SshProfileItem(id: 'p2', name: 'bastion-eu', host: 'bastion.example.net', port: 2222, username: 'ops', privateKeyPath: '/home/ops/.ssh/id_ed25519', authMode: SshAuthMode.privateKey),
];

const _tunnels = [
  TunnelConfigItem(id: 't1', name: 'Dev API', type: TunnelForwardType.local, sshProfileId: 'p1', listenHost: '127.0.0.1', listenPort: 0, targetHost: '127.0.0.1', targetPort: 8080, status: TunnelRuntimeStatus.forwarding),
  TunnelConfigItem(id: 't2', name: 'Webhook', type: TunnelForwardType.remote, sshProfileId: 'p1', listenHost: '0.0.0.0', listenPort: 19090, targetHost: '127.0.0.1', targetPort: 9090, status: TunnelRuntimeStatus.waiting),
  TunnelConfigItem(id: 't3', name: 'Metrics', type: TunnelForwardType.local, sshProfileId: 'p2', listenHost: '127.0.0.1', listenPort: 9100, targetHost: '127.0.0.1', targetPort: 9100, status: TunnelRuntimeStatus.stopped),
];

final bool _enabled = Platform.environment['DECK_GOLDENS'] == '1';

Future<void> _shoot(WidgetTester tester, Widget app, String name) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  testWidgets('connections page', (tester) async {
    if (!_enabled) return;
    await _shoot(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SshProfilesPage(
            profiles: _profiles,
            errorMessage: null,
            onAdd: () {},
            onConnect: (_) {},
            onEdit: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
      'connections',
    );
  });

  testWidgets('tunnels page', (tester) async {
    if (!_enabled) return;
    await _shoot(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: TunnelConfigsPage(
            tunnels: _tunnels,
            profiles: _profiles,
            errorMessage: null,
            onAdd: () {},
            onStart: (_) {},
            onStop: (_) {},
            onEdit: (_) {},
            onDelete: (_) {},
            onTypeChanged: (_, _) {},
          ),
        ),
      ),
      'tunnels',
    );
  });

  testWidgets('theme page', (tester) async {
    if (!_enabled) return;
    await _shoot(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: ThemeConfigPage(
            uiSettings: UiThemeSettings.commandDeck(),
            terminalSettings: TerminalThemeSettings.commandDeck(),
            onUiSettingsChanged: (_) {},
            onTerminalSettingsChanged: (_) {},
            onBack: () {},
          ),
        ),
      ),
      'theme',
    );
  });
}
