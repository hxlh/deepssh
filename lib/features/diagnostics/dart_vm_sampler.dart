import 'dart:async';
import 'dart:developer' as developer;

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Snapshot of Dart VM heap usage and the classes holding the most bytes.
///
/// Sampled via the local VM service. Available in debug and profile builds;
/// release builds strip the service so [connected] stays false.
class DartVmSnapshot {
  const DartVmSnapshot({
    required this.heapUsage,
    required this.heapCapacity,
    required this.externalUsage,
    required this.topClasses,
    required this.connected,
  });

  const DartVmSnapshot.disconnected()
      : heapUsage = 0,
        heapCapacity = 0,
        externalUsage = 0,
        topClasses = const [],
        connected = false;

  final int heapUsage;
  final int heapCapacity;
  final int externalUsage;
  final List<DartClassAllocation> topClasses;
  final bool connected;
}

class DartClassAllocation {
  const DartClassAllocation({
    required this.className,
    required this.instances,
    required this.bytes,
  });

  final String className;
  final int instances;
  final int bytes;
}

/// Connects to the local VM service over the WebSocket exposed by
/// `dart:developer`'s `Service.getInfo()` and runs cheap memory queries.
class DartVmSampler {
  VmService? _service;
  String? _isolateId;
  bool _connecting = false;

  bool get isConnected => _service != null;

  /// Lazily opens a single VM service connection. Safe to call repeatedly —
  /// returns immediately when already connected or while a connection attempt
  /// is in flight. Silently no-ops in release builds where the service is
  /// disabled.
  Future<void> connect() async {
    if (_service != null || _connecting) return;
    _connecting = true;
    try {
      final info = await developer.Service.getInfo();
      final uri = info.serverUri;
      if (uri == null) return;
      final wsUri = _toWebSocketUri(uri);
      final service = await vmServiceConnectUri(wsUri.toString());
      final vm = await service.getVM();
      final isolates = vm.isolates;
      if (isolates == null || isolates.isEmpty) {
        await service.dispose();
        return;
      }
      _service = service;
      _isolateId = isolates.first.id;
    } catch (_) {
      // Connection failed; remain disconnected and let the next sample retry.
    } finally {
      _connecting = false;
    }
  }

  /// Reads heap usage + the top [topN] classes by current bytes. Returns a
  /// disconnected snapshot when the service is unavailable.
  Future<DartVmSnapshot> sample({int topN = 10}) async {
    final service = _service;
    final isolateId = _isolateId;
    if (service == null || isolateId == null) {
      return const DartVmSnapshot.disconnected();
    }
    try {
      final memUsage = await service.getMemoryUsage(isolateId);
      final profile = await service.getAllocationProfile(isolateId);
      final members = profile.members ?? const <ClassHeapStats>[];
      final entries = <DartClassAllocation>[];
      for (final member in members) {
        final bytes = member.bytesCurrent ?? 0;
        if (bytes <= 0) continue;
        entries.add(DartClassAllocation(
          className: member.classRef?.name ?? '<unknown>',
          instances: member.instancesCurrent ?? 0,
          bytes: bytes,
        ));
      }
      entries.sort((a, b) => b.bytes.compareTo(a.bytes));
      final top = entries.length > topN ? entries.sublist(0, topN) : entries;
      return DartVmSnapshot(
        heapUsage: memUsage.heapUsage ?? 0,
        heapCapacity: memUsage.heapCapacity ?? 0,
        externalUsage: memUsage.externalUsage ?? 0,
        topClasses: top,
        connected: true,
      );
    } catch (_) {
      return const DartVmSnapshot.disconnected();
    }
  }

  /// Triggers a full GC and resets the per-class accumulators. No-op when
  /// disconnected.
  Future<void> forceGc() async {
    final service = _service;
    final isolateId = _isolateId;
    if (service == null || isolateId == null) return;
    try {
      await service.getAllocationProfile(isolateId, gc: true, reset: true);
    } catch (_) {
      // Ignore; surfaces in the next sample.
    }
  }

  Future<void> dispose() async {
    final service = _service;
    _service = null;
    _isolateId = null;
    await service?.dispose();
  }

  Uri _toWebSocketUri(Uri uri) {
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final path = uri.path.endsWith('/') ? '${uri.path}ws' : '${uri.path}/ws';
    return uri.replace(scheme: scheme, path: path);
  }
}
