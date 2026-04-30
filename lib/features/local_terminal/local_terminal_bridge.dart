import '../../src/rust/rust_init.dart';
import '../../src/rust/local_terminal.dart' as rust;

class LocalTerminalConnectionResult {
  const LocalTerminalConnectionResult({
    required this.sessionId,
    required this.title,
  });

  final String sessionId;
  final String title;
}

abstract class LocalTerminalBridgeClient {
  Future<LocalTerminalConnectionResult> spawnLocalTerminal({
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
}

class RustLocalTerminalBridgeClient implements LocalTerminalBridgeClient {
  RustLocalTerminalBridgeClient();

  Future<void> _ensureInitialized() {
    return ensureRustInitialized();
  }

  @override
  Future<LocalTerminalConnectionResult> spawnLocalTerminal({
    int? rows,
    int? cols,
  }) async {
    await _ensureInitialized();
    final session = await rust.spawnLocalTerminal(rows: rows, cols: cols);
    return LocalTerminalConnectionResult(
      sessionId: session.sessionId,
      title: session.title,
    );
  }

  @override
  Stream<List<int>> outputStream(String sessionId) async* {
    await _ensureInitialized();
    yield* rust.createLocalTerminalOutputStream(sessionId: sessionId);
  }

  @override
  Future<void> writeToSession(String sessionId, List<int> data) async {
    await _ensureInitialized();
    await rust.writeToLocalTerminal(sessionId: sessionId, data: data);
  }

  @override
  Future<void> resizeSession({
    required String sessionId,
    required int rows,
    required int cols,
  }) async {
    await _ensureInitialized();
    await rust.resizeLocalTerminal(
      sessionId: sessionId,
      rows: rows,
      cols: cols,
    );
  }

  @override
  Future<void> closeSession(String sessionId) async {
    await _ensureInitialized();
    await rust.closeLocalTerminal(sessionId: sessionId);
  }
}

class InMemoryLocalTerminalBridgeClient implements LocalTerminalBridgeClient {
  var _nextSessionId = 1;
  final _closedSessionIds = <String>{};

  List<String> get closedSessionIds => List.unmodifiable(_closedSessionIds);

  @override
  Future<LocalTerminalConnectionResult> spawnLocalTerminal({
    int? rows,
    int? cols,
  }) async {
    return LocalTerminalConnectionResult(
      sessionId: 'local-session-${_nextSessionId++}',
      title: 'terminal',
    );
  }

  @override
  Stream<List<int>> outputStream(String sessionId) {
    return Stream<List<int>>.value(const <int>[]);
  }

  @override
  Future<void> writeToSession(String sessionId, List<int> data) async {}

  @override
  Future<void> resizeSession({
    required String sessionId,
    required int rows,
    required int cols,
  }) async {}

  @override
  Future<void> closeSession(String sessionId) async {
    _closedSessionIds.add(sessionId);
  }
}
