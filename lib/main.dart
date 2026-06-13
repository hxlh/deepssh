import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/logging/app_logger.dart';
import 'core/logging/frontend_error_hooks.dart';
import 'core/models/ssh_profile_item.dart';
import 'core/models/theme_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/version_info.dart';
import 'features/ssh/ssh_bridge.dart';
import 'features/theme/theme_bridge.dart';
import 'workbench/workbench_page.dart';

Future<void> main(List<String> args) async {
  // Bind early so we can touch PaintingBinding before the first frame.
  WidgetsFlutterBinding.ensureInitialized();
  // Default maximumSizeBytes is 100 MiB which is way too generous for a
  // terminal app that barely shows images. Capping at 10 MiB / 100 entries
  // keeps the cache from holding decoded bitmaps after view changes.
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 100;
  imageCache.maximumSizeBytes = 10 << 20;

  // Print version info in debug mode
  if (kDebugMode) {
    ScrollFixInfo.printInfo();
  }

  if (shouldEnableVmService(args)) {
    await _enableVmService();
  }

  runLoggedApp(const DeepSshApp());
}

bool shouldEnableVmService(List<String> args) {
  return args.contains('--vm');
}

Future<void> _enableVmService() async {
  final info = await developer.Service.controlWebServer(
    enable: true,
    silenceOutput: false,
  );
  final uri = info.serverUri;
  if (uri == null) {
    throw StateError('Dart VM Service did not return a server URI.');
  }
  final message = 'Dart VM Service listening at $uri';
  stderr.writeln(message);
  await _writeStartupLog(message);
}

Future<void> _writeStartupLog(String message) async {
  final timestamp = DateTime.now().toLocal();
  final platform = AppLogPlatform.current();
  final logDirectory = platform.logDirectory();
  await logDirectory.create(recursive: true);
  final logFile = File(
    [
      logDirectory.path,
      'frontend-${_dateStamp(timestamp)}.log',
    ].join(Platform.pathSeparator),
  );
  await logFile.writeAsString(
    '${timestamp.toIso8601String()} INFO frontend vm_service\n$message\n',
    mode: FileMode.append,
    flush: true,
  );
}

String _dateStamp(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
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
    required SshAuthMode authMode,
    required String password,
    required String privateKeyPath,
    required String termType,
  }) => _delegate.createProfile(
    name: name,
    host: host,
    port: port,
    username: username,
    authMode: authMode,
    password: password,
    privateKeyPath: privateKeyPath,
    termType: termType,
  );

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
  }) => _delegate.updateProfile(
    id: id,
    name: name,
    host: host,
    port: port,
    username: username,
    authMode: authMode,
    password: password,
    privateKeyPath: privateKeyPath,
    termType: termType,
  );

  @override
  Future<void> deleteProfile(String id) => _delegate.deleteProfile(id);

  @override
  Future<SshConnectionResult> connectProfile(
    String id, {
    String? password,
    String? passphrase,
    int? rows,
    int? cols,
  }) => _delegate.connectProfile(
    id,
    password: password,
    passphrase: passphrase,
    rows: rows,
    cols: cols,
  );

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
