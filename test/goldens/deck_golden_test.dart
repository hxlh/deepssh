// Headless render checks for the deck redesign.
//
// Opt-in review aid, not a pass/fail gate:
//
//   DECK_GOLDENS=1 flutter test test/goldens/deck_golden_test.dart --update-goldens
//
// The CJK fallback is bundled in pubspec.yaml so Chinese text renders in the
// headless Flutter engine without depending on fonts installed on the host.
// The test remains opt-in because golden pixels are still platform-dependent.
import 'dart:io';

import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/core/theme/app_colors.dart';
import 'package:deepssh/core/theme/app_theme.dart';
import 'package:deepssh/core/models/tunnel_config_item.dart';
import 'package:deepssh/features/ssh_profiles/ssh_profile_form_drawer.dart';
import 'package:deepssh/features/ssh_profiles/ssh_profiles_page.dart';
import 'package:deepssh/features/terminal/terminal_state.dart';
import 'package:deepssh/features/terminal/terminal_status_bar.dart';
import 'package:deepssh/core/storage/theme_preset_store.dart';
import 'package:deepssh/features/theme_config/theme_config_page.dart';
import 'package:deepssh/features/tunnels/tunnel_config_form_drawer.dart';
import 'package:deepssh/features/tunnels/tunnel_configs_page.dart';
import 'package:deepssh/workbench/events/workbench_events.dart';
import 'package:deepssh/workbench/widgets/app_topbar.dart';
import 'package:deepssh/workbench/widgets/tab_strip.dart';
import 'package:deepssh/workbench/widgets/workbench_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
bool _goldenFontLoaded = false;

Future<void> _loadGoldenFont() async {
  if (_goldenFontLoaded) return;
  const aliases = [
    'Noto Sans SC',
    'JetBrains Mono',
    'Georgia',
    'Inter',
    'Segoe UI',
    'Consolas',
    'SF Mono',
    'Menlo',
    'Ahem',
    'sans-serif',
    'Roboto',
  ];
  for (final family in aliases) {
    await (FontLoader(
      family,
    )..addFont(rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf'))).load();
  }
  _goldenFontLoaded = true;
}

Future<void> _shoot(WidgetTester tester, Widget app, String name) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final previousFontFamily = AppColors.fontFamily;
  AppColors.fontFamily = 'Noto Sans SC';
  addTearDown(() => AppColors.fontFamily = previousFontFamily);
  await _loadGoldenFont();
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

/// Applies a UI preset for the duration of one render, then restores the deck
/// defaults. [AppColors] is process-global, so this has to be undone or the
/// next golden inherits the previous one's palette.
Future<void> _withUiTheme(
  WidgetTester tester,
  UiThemeSettings settings,
  Future<void> Function(WidgetTester) body,
) async {
  addTearDown(() => AppColors.applyUi(UiThemeSettings.commandDeck()));
  AppColors.applyUi(settings);
  await body(tester);
}

void main() {
  if (_enabled) {
    AppColors.fontFamily = 'Noto Sans SC';
  }

  testWidgets('connections page under a dark preset', (tester) async {
    if (!_enabled) return;
    await _withUiTheme(tester, UiThemeSettings.vsCodeDark(), (tester) async {
      await _shoot(
        tester,
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.deck(),
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
        'connections-dark',
      );
    });
  });

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
    // Fixed timestamps: `record` defaults to DateTime.now(), which would make
    // the dock golden shift on every run (the feed renders hh:mm:ss).
    final t = DateTime(2026, 10, 4, 14, 32);
    final events = WorkbenchEvents()
      ..record(
        WorkbenchEventLevel.error,
        '转发启动失败',
        subject: 'db-5432 · port 10048',
        time: t,
      )
      ..record(
        WorkbenchEventLevel.warn,
        '转发已停止',
        subject: 'web-8080',
        time: t.add(const Duration(seconds: 3)),
      )
      ..record(
        WorkbenchEventLevel.info,
        '已连接',
        subject: 'deploy@10.24.8.11:22',
        time: t.add(const Duration(seconds: 13)),
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
            onCollapsedChanged: (_) {},
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
            onCollapsedChanged: (_) {},
            onHeightChanged: (_) {},
          ),
        ),
      ),
      'dock-no-memory',
    );
  });

  testWidgets('ssh form drawer over the connections list', (tester) async {
    if (!_enabled) return;
    await _shoot(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Stack(
            children: [
              SshProfilesPage(
                profiles: _profiles,
                errorMessage: null,
                onAdd: () {},
                onConnect: (_) {},
                onEdit: (_) {},
                onDelete: (_) {},
              ),
              SshProfileFormDrawer(onCancel: () {}, onSaved: (_) {}),
            ],
          ),
        ),
      ),
      'ssh-drawer',
    );
  });

  testWidgets('tunnel form drawer over the tunnels list', (tester) async {
    if (!_enabled) return;
    await _shoot(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Stack(
            children: [
              TunnelConfigsPage(
                tunnels: _tunnels,
                profiles: _profiles,
                errorMessage: null,
                onAdd: () {},
                onStart: (_) {},
                onStop: (_) {},
                onEdit: (_) {},
                onDelete: (_) {},
              ),
              TunnelConfigFormDrawer(
                profiles: _profiles,
                onCancel: () {},
                onSaved: (_) {},
              ),
            ],
          ),
        ),
      ),
      'tunnel-drawer',
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
            presetStore: InMemoryThemePresetStore(),
          ),
        ),
      ),
      'theme',
    );
  });
}
