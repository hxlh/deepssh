import '../../core/models/ssh_profile_item.dart';
import '../../src/rust/frb_generated.dart';
import '../../src/rust/profile.dart' as rust_profile;
import '../../src/rust/ssh_session.dart' as rust_session;

class SshConnectionResult {
  const SshConnectionResult({required this.sessionId, required this.title});

  final String sessionId;
  final String title;
}

abstract class SshBridgeClient {
  Future<List<SshProfileItem>> listProfiles();

  Future<SshProfileItem> createProfile({
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    required String termType,
  });

  Future<SshProfileItem> updateProfile({
    required String id,
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    required String termType,
  });

  Future<void> deleteProfile(String id);

  Future<SshConnectionResult> connectProfile(
    String id, {
    int? rows,
    int? cols,
  });

  Stream<List<int>> outputStream(String sessionId);

  Future<void> writeToSession(String sessionId, List<int> data);

  Future<void> resizeSession({
    required String sessionId,
    required int rows,
    required int cols,
  });

  Future<void> closeSession(String sessionId);

  Future<SshConnectionResult> duplicateSession(String sessionId);
}

class RustSshBridgeClient implements SshBridgeClient {
  RustSshBridgeClient();

  Future<void>? _initFuture;

  Future<void> _ensureInitialized() {
    return _initFuture ??= RustLib.init();
  }

  @override
  Future<List<SshProfileItem>> listProfiles() async {
    await _ensureInitialized();
    final profiles = await rust_profile.listProfiles();
    return profiles.map(_toItem).toList(growable: false);
  }

  @override
  Future<SshProfileItem> createProfile({
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    required String termType,
  }) async {
    await _ensureInitialized();
    final profile = await rust_profile.createProfile(
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
      termType: termType,
    );
    return _toItem(profile);
  }

  @override
  Future<SshProfileItem> updateProfile({
    required String id,
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    required String termType,
  }) async {
    await _ensureInitialized();
    final profile = await rust_profile.updateProfile(
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
      termType: termType,
    );
    return _toItem(profile);
  }

  @override
  Future<void> deleteProfile(String id) async {
    await _ensureInitialized();
    await rust_profile.deleteProfile(id: id);
  }

  @override
  Future<SshConnectionResult> connectProfile(
    String id, {
    int? rows,
    int? cols,
  }) async {
    await _ensureInitialized();
    final profiles = await rust_profile.listProfiles();
    final profile = profiles.firstWhere((profile) => profile.id == id);
    final session = await rust_session.connectProfile(
      profileId: profile.id,
      title: profile.name,
      host: profile.host,
      port: profile.port,
      username: profile.username,
      password: profile.password,
      termType: profile.termType,
      rows: rows ?? 24,
      cols: cols ?? 80,
    );
    return SshConnectionResult(
      sessionId: session.sessionId,
      title: session.title,
    );
  }

  @override
  Stream<List<int>> outputStream(String sessionId) async* {
    await _ensureInitialized();
    yield* rust_session.createOutputStream(sessionId: sessionId);
  }

  @override
  Future<void> writeToSession(String sessionId, List<int> data) async {
    await _ensureInitialized();
    await rust_session.writeToSession(sessionId: sessionId, data: data);
  }

  @override
  Future<void> resizeSession({
    required String sessionId,
    required int rows,
    required int cols,
  }) async {
    await _ensureInitialized();
    await rust_session.resizeSession(
      sessionId: sessionId,
      rows: rows,
      cols: cols,
    );
  }

  @override
  Future<void> closeSession(String sessionId) async {
    await _ensureInitialized();
    await rust_session.closeSession(sessionId: sessionId);
  }

  @override
  Future<SshConnectionResult> duplicateSession(String sessionId) async {
    await _ensureInitialized();
    final session = await rust_session.duplicateSession(sessionId: sessionId);
    return SshConnectionResult(
      sessionId: session.sessionId,
      title: session.title,
    );
  }

  SshProfileItem _toItem(rust_profile.SshProfile profile) {
    return SshProfileItem(
      id: profile.id,
      name: profile.name,
      host: profile.host,
      port: profile.port,
      username: profile.username,
      password: profile.password,
      termType: profile.termType,
    );
  }
}

class InMemorySshBridgeClient implements SshBridgeClient {
  final List<SshProfileItem> _profiles = [];
  var _nextProfileId = 1;
  var _nextSessionId = 1;

  @override
  Future<List<SshProfileItem>> listProfiles() async =>
      List.unmodifiable(_profiles);

  @override
  Future<SshProfileItem> createProfile({
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    required String termType,
  }) async {
    final profile = SshProfileItem(
      id: 'profile-${_nextProfileId++}',
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
      termType: termType,
    );
    _profiles.add(profile);
    return profile;
  }

  @override
  Future<SshProfileItem> updateProfile({
    required String id,
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    required String termType,
  }) async {
    final index = _profiles.indexWhere((profile) => profile.id == id);
    if (index == -1) {
      throw StateError('Profile not found');
    }
    final profile = SshProfileItem(
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
      termType: termType,
    );
    _profiles[index] = profile;
    return profile;
  }

  @override
  Future<void> deleteProfile(String id) async {
    _profiles.removeWhere((profile) => profile.id == id);
  }

  @override
  Future<SshConnectionResult> connectProfile(
    String id, {
    int? rows,
    int? cols,
  }) async {
    final profile = _profiles.firstWhere((profile) => profile.id == id);
    return SshConnectionResult(
      sessionId: 'ssh-session-${_nextSessionId++}',
      title: profile.name,
    );
  }

  @override
  Stream<List<int>> outputStream(String sessionId) => Stream.value(const []);

  @override
  Future<void> writeToSession(String sessionId, List<int> data) async {}

  @override
  Future<void> resizeSession({
    required String sessionId,
    required int rows,
    required int cols,
  }) async {}

  @override
  Future<void> closeSession(String sessionId) async {}

  @override
  Future<SshConnectionResult> duplicateSession(String sessionId) async {
    return SshConnectionResult(
      sessionId: 'ssh-session-${_nextSessionId++}',
      title: 'duplicated',
    );
  }
}
