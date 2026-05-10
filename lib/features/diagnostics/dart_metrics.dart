import 'dart:io';

/// Memory numbers visible from the Dart side of the process.
///
/// `processCurrentRss` and `processMaxRss` come from `dart:io` `ProcessInfo`,
/// which on Windows reports the working set / peak working set in bytes. This
/// is the same number Task Manager shows; it is the most reliable signal we
/// have without round-tripping through the VM service.
class DartMemSnapshot {
  const DartMemSnapshot({
    required this.processCurrentRss,
    required this.processMaxRss,
  });

  const DartMemSnapshot.zero()
      : processCurrentRss = 0,
        processMaxRss = 0;

  final int processCurrentRss;
  final int processMaxRss;
}

DartMemSnapshot collectDartMetrics() {
  return DartMemSnapshot(
    processCurrentRss: ProcessInfo.currentRss,
    processMaxRss: ProcessInfo.maxRss,
  );
}
