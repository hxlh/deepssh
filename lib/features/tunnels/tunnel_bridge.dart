import '../../core/models/tunnel_config_item.dart';
import '../../src/rust/frb_generated.dart';
import '../../src/rust/tunnel.dart' as rust;

abstract class TunnelBridgeClient {
  Future<List<TunnelConfigItem>> listTunnels();

  Future<TunnelConfigItem> createTunnel({
    required String name,
    required TunnelForwardType type,
    required String sshProfileId,
    required String listenHost,
    required int listenPort,
    required String targetHost,
    required int targetPort,
  });

  Future<TunnelConfigItem> updateTunnel({
    required String id,
    required String name,
    required TunnelForwardType type,
    required String sshProfileId,
    required String listenHost,
    required int listenPort,
    required String targetHost,
    required int targetPort,
  });

  Future<void> deleteTunnel(String id);

  Future<TunnelConfigItem> startTunnel(String id);

  Future<TunnelConfigItem> stopTunnel(String id);
}

class InMemoryTunnelBridgeClient implements TunnelBridgeClient {
  final List<TunnelConfigItem> _tunnels = [];
  var _nextTunnelId = 1;

  @override
  Future<List<TunnelConfigItem>> listTunnels() async =>
      List.unmodifiable(_tunnels);

  @override
  Future<TunnelConfigItem> createTunnel({
    required String name,
    required TunnelForwardType type,
    required String sshProfileId,
    required String listenHost,
    required int listenPort,
    required String targetHost,
    required int targetPort,
  }) async {
    final tunnel = TunnelConfigItem(
      id: 'tunnel-${_nextTunnelId++}',
      name: name,
      type: type,
      sshProfileId: sshProfileId,
      listenHost: listenHost,
      listenPort: listenPort,
      targetHost: targetHost,
      targetPort: targetPort,
    );
    _tunnels.add(tunnel);
    return tunnel;
  }

  @override
  Future<TunnelConfigItem> updateTunnel({
    required String id,
    required String name,
    required TunnelForwardType type,
    required String sshProfileId,
    required String listenHost,
    required int listenPort,
    required String targetHost,
    required int targetPort,
  }) async {
    final index = _tunnels.indexWhere((tunnel) => tunnel.id == id);
    if (index == -1) {
      throw StateError('Tunnel not found');
    }
    final tunnel = TunnelConfigItem(
      id: id,
      name: name,
      type: type,
      sshProfileId: sshProfileId,
      listenHost: listenHost,
      listenPort: listenPort,
      targetHost: targetHost,
      targetPort: targetPort,
      status: _tunnels[index].status,
    );
    _tunnels[index] = tunnel;
    return tunnel;
  }

  @override
  Future<void> deleteTunnel(String id) async {
    _tunnels.removeWhere((tunnel) => tunnel.id == id);
  }

  @override
  Future<TunnelConfigItem> startTunnel(String id) async {
    return _replaceStatus(id, TunnelRuntimeStatus.forwarding);
  }

  @override
  Future<TunnelConfigItem> stopTunnel(String id) async {
    return _replaceStatus(id, TunnelRuntimeStatus.stopped);
  }

  TunnelConfigItem _replaceStatus(String id, TunnelRuntimeStatus status) {
    final index = _tunnels.indexWhere((tunnel) => tunnel.id == id);
    if (index == -1) {
      throw StateError('Tunnel not found');
    }
    final tunnel = _tunnels[index].copyWith(status: status);
    _tunnels[index] = tunnel;
    return tunnel;
  }
}

TunnelForwardType _toForwardType(rust.TunnelForwardType type) {
  switch (type) {
    case rust.TunnelForwardType.local:
      return TunnelForwardType.local;
    case rust.TunnelForwardType.remote:
      return TunnelForwardType.remote;
  }
}

rust.TunnelForwardType _toRustForwardType(TunnelForwardType type) {
  switch (type) {
    case TunnelForwardType.local:
      return rust.TunnelForwardType.local;
    case TunnelForwardType.remote:
      return rust.TunnelForwardType.remote;
  }
}

TunnelRuntimeStatus _toRuntimeStatus(rust.TunnelRuntimeStatus status) {
  switch (status) {
    case rust.TunnelRuntimeStatus.stopped:
      return TunnelRuntimeStatus.stopped;
    case rust.TunnelRuntimeStatus.waiting:
      return TunnelRuntimeStatus.waiting;
    case rust.TunnelRuntimeStatus.forwarding:
      return TunnelRuntimeStatus.forwarding;
  }
}

TunnelConfigItem _toTunnelConfigItem(rust.TunnelConfig config) {
  return TunnelConfigItem(
    id: config.id,
    name: config.name,
    type: _toForwardType(config.forwardType),
    sshProfileId: config.sshProfileId,
    listenHost: config.listenHost,
    listenPort: config.listenPort,
    targetHost: config.targetHost,
    targetPort: config.targetPort,
    status: _toRuntimeStatus(config.status),
  );
}

class RustTunnelBridgeClient implements TunnelBridgeClient {
  RustTunnelBridgeClient();

  Future<void>? _initFuture;

  Future<void> _ensureInitialized() {
    return _initFuture ??= RustLib.init();
  }

  @override
  Future<List<TunnelConfigItem>> listTunnels() async {
    await _ensureInitialized();
    final configs = await rust.listTunnels();
    return configs.map(_toTunnelConfigItem).toList();
  }

  @override
  Future<TunnelConfigItem> createTunnel({
    required String name,
    required TunnelForwardType type,
    required String sshProfileId,
    required String listenHost,
    required int listenPort,
    required String targetHost,
    required int targetPort,
  }) async {
    await _ensureInitialized();
    final config = await rust.createTunnel(
      name: name,
      forwardType: _toRustForwardType(type),
      sshProfileId: sshProfileId,
      listenHost: listenHost,
      listenPort: listenPort,
      targetHost: targetHost,
      targetPort: targetPort,
    );
    return _toTunnelConfigItem(config);
  }

  @override
  Future<TunnelConfigItem> updateTunnel({
    required String id,
    required String name,
    required TunnelForwardType type,
    required String sshProfileId,
    required String listenHost,
    required int listenPort,
    required String targetHost,
    required int targetPort,
  }) async {
    await _ensureInitialized();
    final config = await rust.updateTunnel(
      id: id,
      name: name,
      forwardType: _toRustForwardType(type),
      sshProfileId: sshProfileId,
      listenHost: listenHost,
      listenPort: listenPort,
      targetHost: targetHost,
      targetPort: targetPort,
    );
    return _toTunnelConfigItem(config);
  }

  @override
  Future<void> deleteTunnel(String id) async {
    await _ensureInitialized();
    await rust.deleteTunnel(id: id);
  }

  @override
  Future<TunnelConfigItem> startTunnel(String id) async {
    await _ensureInitialized();
    final config = await rust.startTunnel(id: id);
    return _toTunnelConfigItem(config);
  }

  @override
  Future<TunnelConfigItem> stopTunnel(String id) async {
    await _ensureInitialized();
    final config = await rust.stopTunnel(id: id);
    return _toTunnelConfigItem(config);
  }
}
