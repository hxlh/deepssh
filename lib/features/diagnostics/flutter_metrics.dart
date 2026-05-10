import 'package:flutter/painting.dart';

/// Snapshot of the Flutter image cache. Useful when the OS-level RSS keeps
/// climbing after closing tabs — large decoded images linger here long after
/// the widget that loaded them is gone.
class FlutterMemSnapshot {
  const FlutterMemSnapshot({
    required this.imageCacheCurrentSize,
    required this.imageCacheCurrentBytes,
    required this.liveImageCount,
    required this.pendingImageCount,
    required this.maximumSize,
    required this.maximumSizeBytes,
  });

  const FlutterMemSnapshot.zero()
      : imageCacheCurrentSize = 0,
        imageCacheCurrentBytes = 0,
        liveImageCount = 0,
        pendingImageCount = 0,
        maximumSize = 0,
        maximumSizeBytes = 0;

  final int imageCacheCurrentSize;
  final int imageCacheCurrentBytes;
  final int liveImageCount;
  final int pendingImageCount;
  final int maximumSize;
  final int maximumSizeBytes;
}

FlutterMemSnapshot collectFlutterMetrics() {
  final cache = PaintingBinding.instance.imageCache;
  return FlutterMemSnapshot(
    imageCacheCurrentSize: cache.currentSize,
    imageCacheCurrentBytes: cache.currentSizeBytes,
    liveImageCount: cache.liveImageCount,
    pendingImageCount: cache.pendingImageCount,
    maximumSize: cache.maximumSize,
    maximumSizeBytes: cache.maximumSizeBytes,
  );
}

void trimImageCache() {
  final cache = PaintingBinding.instance.imageCache;
  cache.clear();
  cache.clearLiveImages();
}
