import 'package:flutter/material.dart';

import 'core/models/ssh_profile_item.dart';
import 'core/theme/app_theme.dart';
import 'features/ssh/ssh_bridge.dart';
import 'workbench/workbench_page.dart';

void main() {
  runApp(const DeepSshApp());
}

class DeepSshApp extends StatelessWidget {
  const DeepSshApp({super.key, SshBridgeClient? sshBridge})
    : sshBridge = sshBridge ?? const _DefaultAppSshBridgeClientHolder();

  final SshBridgeClient sshBridge;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DeepSSH',
      theme: AppTheme.dark(),
      home: WorkbenchPage(sshBridge: sshBridge),
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
  Future<SshConnectionResult> connectProfile(String id) => _delegate.connectProfile(id);

  @override
  Stream<List<int>> outputStream(String sessionId) => _delegate.outputStream(sessionId);

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
  Future<void> closeSession(String sessionId) => _delegate.closeSession(sessionId);
}
