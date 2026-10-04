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
import 'package:deepssh/features/terminal/terminal_state.dart';
import 'package:deepssh/features/terminal/terminal_status_bar.dart';
import 'package:deepssh/features/theme_config/theme_config_page.dart';
import 'package:deepssh/features/tunnels/tunnel_configs_page.dart';
import 'package:deepssh/workbench/events/workbench_events.dart';
import 'package:deepssh/workbench/widgets/app_topbar.dart';
import 'package:deepssh/workbench/widgets/tab_strip.dart';
import 'package:deepssh/workbench/widgets/workbench_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profiles = [
  SshProfileItem(
    id: 'p1',
    name: 'prod-web-01',
    host: '10.0.3.17',
    port: 22,
    username: 'deploy',
  ),
  SshProfileItem(
    id: 'p2',
    name: 'bastion-eu',
    host: 'bastion.example.net',
    port: 2222,
    username: 'ops',
    privateKeyPath: '/home/ops/.ssh/id_ed25519',
    authMode: SshAuthMode.privateKey,
  ),
];

const _tunnels = [
  TunnelConfigItem(
    id: 't1',
    name: 'Dev API',
    type: TunnelForwardType.local,
    sshProfileId: 'p1',
    listenHost: '127.0.0.1',
    listenPort: 0,
    targetHost: '127.0.0.1',
    targetPort: 8080,
    status: TunnelRuntimeStatus.forwarding,
  ),
  TunnelConfigItem(
    id: 't2',
    name: 'Webhook',
    type: TunnelForwardType.remote,
    sshProfileId: 'p1',
    listenHost: '0.0.0.0',
    listenPort: 19090,
    targetHost: '127.0.0.1',
    targetPort: 9090,
    status: TunnelRuntimeStatus.waiting,
  ),
  TunnelConfigItem(
    id: 't3',
    name: 'Metrics',
    type: TunnelForwardType.local,
    sshProfileId: 'p2',
    listenHost: '127.0.0.1',
    listenPort: 9100,
    targetHost: '127.0.0.1',
    targetPort: 9100,
    status: TunnelRuntimeStatus.stopped,
  ),
];

final bool _enabled = Platform.environment['DECK_GOLDENS'] == '1';

Future<void> _shoot(WidgetTester tester, Widget app, String name) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
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
          ),
        ),
      ),
      'tunnels',
    );
  });

  testWidgets('workbench dock', (tester) async {
    if (!_enabled) return;
    final events = WorkbenchEvents()
      ..record(
        WorkbenchEventLevel.error,
        '转发启动失败',
        subject: 'db-5432 · port 10048',
      )
      ..record(WorkbenchEventLevel.warn, '转发已停止', subject: 'web-8080')
      ..record(
        WorkbenchEventLevel.info,
        '已连接',
        subject: 'deploy@10.24.8.11:22',
      );
    await _shoot(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: WorkbenchDock(
            events: events,
            height: 260,
            collapsed: false,
            showMemory: true,
            onToggleCollapsed: () {},
            onHeightChanged: (_) {},
          ),
        ),
      ),
      'dock',
    );

    // 内存监控 toggled off from the Explorer footer: the panel and the inner
    // splitter leave the row and 实时事件 takes the full width.
    await _shoot(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: WorkbenchDock(
            events: events,
            height: 260,
            collapsed: false,
            showMemory: false,
            onToggleCollapsed: () {},
            onHeightChanged: (_) {},
          ),
        ),
      ),
      'dock-no-memory',
    );
  });

  testWidgets('topbar', (tester) async {
    if (!_enabled) return;
    await _shoot(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: AppTopBar(
            current: AppSection.workbench,
            onNavigate: (_) {},
            onAddConnection: (_) {},
            sessionCount: 4,
            tunnelCount: 2,
            memoryRssMb: 142.6,
            clock: DateTime(2026, 10, 4, 14, 32),
          ),
        ),
      ),
      'topbar',
    );
  });

  testWidgets('tab strip and terminal status bar', (tester) async {
    if (!_enabled) return;
    final tabs = [
      const OpenTerminalTab(
        id: 't1',
        hostId: 'ssh',
        hostName: 'prod-web-01',
        title: 'prod-web-01',
        sourceType: TerminalSourceType.ssh,
        termType: 'xterm-256color',
      ),
      OpenTerminalTab.local(id: 't2', title: '本地终端'),
    ];
    await _shoot(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Column(
            children: [
              TabStrip(
                tabs: tabs,
                activeTabId: 't1',
                onSelect: (_) {},
                onClose: (_) {},
                onReorder: (_, _) {},
              ),
              const Spacer(),
              TerminalStatusBar(tab: tabs.first, connected: true),
            ],
          ),
        ),
      ),
      'terminal-chrome',
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
