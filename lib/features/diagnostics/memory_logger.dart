import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/logging/app_logger.dart';

class MemoryLogRow {
  const MemoryLogRow({
    required this.rustCurrentRss,
    required this.rustPeakRss,
    required this.dartCurrentRss,
    required this.dartMaxRss,
    required this.imageCacheBytes,
    required this.liveImages,
    required this.sshSessions,
    required this.localTerminals,
    required this.tunnelsRunning,
    this.dartHeapUsage = 0,
    this.dartHeapCapacity = 0,
    this.dartExternalUsage = 0,
  });

  final int rustCurrentRss;
  final int rustPeakRss;
  final int dartCurrentRss;
  final int dartMaxRss;
  final int imageCacheBytes;
  final int liveImages;
  final int sshSessions;
  final int localTerminals;
  final int tunnelsRunning;
  final int dartHeapUsage;
  final int dartHeapCapacity;
  final int dartExternalUsage;

  static const header =
      'timestamp,rust_current_rss,rust_peak_rss,dart_current_rss,dart_max_rss,'
      'image_cache_bytes,live_images,ssh_sessions,local_terminals,tunnels_running,'
      'dart_heap_usage,dart_heap_capacity,dart_external_usage';

  String toCsv(DateTime timestamp) {
    return '${timestamp.toIso8601String()},'
        '$rustCurrentRss,$rustPeakRss,$dartCurrentRss,$dartMaxRss,'
        '$imageCacheBytes,$liveImages,$sshSessions,$localTerminals,$tunnelsRunning,'
        '$dartHeapUsage,$dartHeapCapacity,$dartExternalUsage';
  }
}

class MemoryLogger {
  MemoryLogger({
    Directory Function()? logDirectoryProvider,
    DateTime Function()? clock,
  })  : _logDirectoryProvider =
            logDirectoryProvider ?? AppLogPlatform.current().logDirectory,
        _clock = clock ?? DateTime.now;

  final Directory Function() _logDirectoryProvider;
  final DateTime Function() _clock;

  Future<void> writeRow(MemoryLogRow row) async {
    final now = _clock();
    final dir = _logDirectoryProvider();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final fileName =
        'memory-${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv';
    final file = File(p.join(dir.path, fileName));
    final exists = await file.exists();
    final sink = file.openWrite(mode: FileMode.append);
    try {
      if (!exists) {
        sink.writeln(MemoryLogRow.header);
      }
      sink.writeln(row.toCsv(now));
      await sink.flush();
    } finally {
      await sink.close();
    }
  }
}
