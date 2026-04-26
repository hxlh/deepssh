import 'package:flutter/material.dart';

import 'core/models/ssh_profile_item.dart';
import 'core/models/theme_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/ssh/ssh_bridge.dart';
import 'features/theme/theme_bridge.dart';
import 'workbench/workbench_page.dart';

void main() {
  runApp(const DeepSshApp());
}

class DeepSshApp extends StatefulWidget {
  const DeepSshApp({super.key, this.sshBridge, this.themeBridge});

  final SshBridgeClient? sshBridge;
  final ThemeBridgeClient? themeBridge;

  @override
  State<DeepSshApp> createState() => _DeepSshAppState();
}

class _DeepSshAppState extends State<DeepSshApp> {
  late final SshBridgeClient _sshBridge;
  late final ThemeBridgeClient _themeBridge;

  @override
  void initState() {
    super.initState();
    _sshBridge = widget.sshBridge ?? const _DefaultAppSshBridgeClientHolder();
    _themeBridge =
        widget.themeBridge ?? const _DefaultAppThemeBridgeClientHolder();
  }

  void _handleThemeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DeepSSH',
      theme: AppTheme.dark(),
      home: WorkbenchPage(
        sshBridge: _sshBridge,
        themeBridge: _themeBridge,
        onThemeChanged: _handleThemeChanged,
      ),
    );
  }
}

class _DefaultAppSshBridgeClientHolder implements SshBridgeClient {
  const _DefaultAppSshBridgeClientHolder();

  static final RustSshBridgeClient _delegate = RustSshBridgeClient();

  @override
  Future<List<SshProfileItem>> listProfiles() => _delegate.listProfiles();

  @override
  Future<SshProfileItem> createProfile({
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
  }) => _delegate.createProfile(
    name: name,
    host: host,
    port: port,
    username: username,
    password: password,
  );

  @override
  Future<SshProfileItem> updateProfile({
    required String id,
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
  }) => _delegate.updateProfile(
    id: id,
    name: name,
    host: host,
    port: port,
    username: username,
    password: password,
  );

  @override
  Future<void> deleteProfile(String id) => _delegate.deleteProfile(id);

  @override
  Future<SshConnectionResult> connectProfile(String id) =>
      _delegate.connectProfile(id);

  @override
  Stream<List<int>> outputStream(String sessionId) =>
      _delegate.outputStream(sessionId);

  @override
  Future<void> writeToSession(String sessionId, List<int> data) =>
      _delegate.writeToSession(sessionId, data);

  @override
  Future<void> resizeSession({
    required String sessionId,
    required int rows,
    required int cols,
  }) => _delegate.resizeSession(sessionId: sessionId, rows: rows, cols: cols);

  @override
  Future<void> closeSession(String sessionId) =>
      _delegate.closeSession(sessionId);

  @override
  Future<SshConnectionResult> duplicateSession(String sessionId) =>
      _delegate.duplicateSession(sessionId);
}

class _DefaultAppThemeBridgeClientHolder implements ThemeBridgeClient {
  const _DefaultAppThemeBridgeClientHolder();

  static final RustThemeBridgeClient _delegate = RustThemeBridgeClient();

  @override
  Future<({UiThemeSettings ui, TerminalThemeSettings terminal})> loadTheme() =>
      _delegate.loadTheme();

  @override
  Future<void> saveTheme({
    required UiThemeSettings ui,
    required TerminalThemeSettings terminal,
  }) => _delegate.saveTheme(ui: ui, terminal: terminal);
}
