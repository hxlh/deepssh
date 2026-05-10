import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deepssh/features/diagnostics/flutter_metrics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('collectFlutterMetrics mirrors PaintingBinding image cache state', () {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.maximumSize = 64;
    cache.maximumSizeBytes = 1024 * 1024;

    final snapshot = collectFlutterMetrics();

    expect(snapshot.maximumSize, 64);
    expect(snapshot.maximumSizeBytes, 1024 * 1024);
    expect(snapshot.imageCacheCurrentSize, cache.currentSize);
    expect(snapshot.imageCacheCurrentBytes, cache.currentSizeBytes);
    expect(snapshot.liveImageCount, cache.liveImageCount);
    expect(snapshot.pendingImageCount, cache.pendingImageCount);
  });

  test('trimImageCache empties the image cache', () {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = 64;

    trimImageCache();

    expect(cache.currentSize, 0);
    expect(cache.liveImageCount, 0);
  });
}
