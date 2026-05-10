import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:deepssh/features/diagnostics/memory_logger.dart';

void main() {
  test('MemoryLogger writes a header row and one data row per tick', () async {
    final tmp = await Directory.systemTemp.createTemp('mem-log-test-');
    addTearDown(() async {
      if (tmp.existsSync()) {
        await tmp.delete(recursive: true);
      }
    });

    final logger = MemoryLogger(
      logDirectoryProvider: () => tmp,
      clock: () => DateTime.parse('2026-05-09T12:00:00Z'),
    );

    await logger.writeRow(MemoryLogRow(
      rustCurrentRss: 100,
      rustPeakRss: 200,
      dartCurrentRss: 50,
      dartMaxRss: 60,
      imageCacheBytes: 10,
      liveImages: 1,
      sshSessions: 0,
      localTerminals: 0,
      tunnelsRunning: 0,
    ));

    final file = File(p.join(tmp.path, 'memory-2026-05-09.csv'));
    expect(file.existsSync(), isTrue);
    final lines = await file.readAsLines();
    expect(lines.first, startsWith('timestamp,'));
    expect(lines.length, 2);
    expect(lines.last, contains('100,200,50,60,10,1,0,0,0'));
  });
}
