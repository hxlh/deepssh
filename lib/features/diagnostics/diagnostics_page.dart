import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../src/rust/mem_metrics.dart' as rust_mem;
import 'dart_metrics.dart';
import 'dart_vm_sampler.dart';
import 'flutter_metrics.dart';
import 'memory_logger.dart';

typedef RustSnapshotFetcher = Future<rust_mem.RustMemSnapshot> Function();

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({
    super.key,
    required this.onBack,
    this.debugRustFetcher,
    this.debugSnapshotProbe,
  });

  final VoidCallback onBack;

  /// Override the Rust-side fetcher in tests. When null we call the real FFI
  /// `rust_mem.rustMemSnapshot()`.
  final RustSnapshotFetcher? debugRustFetcher;

  /// Optional spy for tests so they can count manual refresh button taps
  /// without instrumenting the FFI bridge.
  final VoidCallback? debugSnapshotProbe;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  static const int _historyLimit = 60;

  rust_mem.RustMemSnapshot? _rustSnapshot;
  DartMemSnapshot _dartSnapshot = const DartMemSnapshot.zero();
  FlutterMemSnapshot _flutterSnapshot = const FlutterMemSnapshot.zero();
  DartVmSnapshot _vmSnapshot = const DartVmSnapshot.disconnected();
  String? _lastError;

  final Queue<int> _rssHistory = ListQueue<int>(_historyLimit);

  Timer? _csvTimer;
  final MemoryLogger _csvLogger = MemoryLogger();
  final DartVmSampler _vmSampler = DartVmSampler();

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _csvTimer?.cancel();
    unawaited(_vmSampler.dispose());
    super.dispose();
  }

  Future<void> _refresh() async {
    widget.debugSnapshotProbe?.call();
    final fetcher = widget.debugRustFetcher;
    rust_mem.RustMemSnapshot? rust;
    String? error;
    if (fetcher != null) {
      try {
        rust = await fetcher();
      } catch (e) {
        error = e.toString();
      }
    } else {
      try {
        rust = await rust_mem.rustMemSnapshot();
      } catch (e) {
        error = e.toString();
      }
    }
    if (!_vmSampler.isConnected) {
      await _vmSampler.connect();
    }
    final vm = await _vmSampler.sample();
    if (!mounted) return;
    setState(() {
      _rustSnapshot = rust;
      _dartSnapshot = collectDartMetrics();
      _flutterSnapshot = collectFlutterMetrics();
      _vmSnapshot = vm;
      _lastError = error;
      final rss = rust?.currentRss.toInt() ?? _dartSnapshot.processCurrentRss;
      if (_rssHistory.length == _historyLimit) {
        _rssHistory.removeFirst();
      }
      _rssHistory.addLast(rss);
    });
  }

  Future<void> _mimallocCollect() async {
    try {
      await rust_mem.rustMimallocCollect();
    } catch (_) {
      // Ignore; surfaces in the next refresh.
    }
    await _refresh();
  }

  Future<void> _forceGc() async {
    await _vmSampler.forceGc();
    await _refresh();
  }

  Future<void> _trimImageCache() async {
    trimImageCache();
    await _refresh();
  }

  Future<void> _toggleCsvLogger() async {
    if (_csvTimer != null) {
      _csvTimer!.cancel();
      _csvTimer = null;
      if (mounted) setState(() {});
      return;
    }
    _csvTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final r = _rustSnapshot;
      await _csvLogger.writeRow(MemoryLogRow(
        rustCurrentRss: r?.currentRss.toInt() ?? 0,
        rustPeakRss: r?.peakRss.toInt() ?? 0,
        dartCurrentRss: _dartSnapshot.processCurrentRss,
        dartMaxRss: _dartSnapshot.processMaxRss,
        imageCacheBytes: _flutterSnapshot.imageCacheCurrentBytes,
        liveImages: _flutterSnapshot.liveImageCount,
        sshSessions: r?.sshSessions.toInt() ?? 0,
        localTerminals: r?.localTerminals.toInt() ?? 0,
        tunnelsRunning: r?.tunnelsRunning.toInt() ?? 0,
        dartHeapUsage: _vmSnapshot.heapUsage,
        dartHeapCapacity: _vmSnapshot.heapCapacity,
        dartExternalUsage: _vmSnapshot.externalUsage,
      ));
      await _refresh();
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(foregroundColor: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              const Text(
                '内存监控',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(label: 'Refresh', onPressed: _refresh),
              _ActionButton(label: 'Mimalloc Collect', onPressed: _mimallocCollect),
              _ActionButton(label: 'Force GC', onPressed: _forceGc),
              _ActionButton(label: 'Trim Image Cache', onPressed: _trimImageCache),
              _ActionButton(
                label: _csvTimer == null ? 'Start CSV log' : 'Stop CSV log',
                onPressed: _toggleCsvLogger,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_lastError != null) _ErrorBanner(message: _lastError!),
                  _SectionCard(
                    title: 'RSS history (last 60 samples)',
                    child: SizedBox(
                      height: 120,
                      child: CustomPaint(
                        painter: _RssChartPainter(
                          samples: _rssHistory.toList(growable: false),
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(title: 'Rust', child: _buildRustSection()),
                  const SizedBox(height: 20),
                  _SectionCard(title: 'Dart', child: _buildDartSection()),
                  const SizedBox(height: 20),
                  _SectionCard(
                    title: 'Dart VM heap (debug/profile only)',
                    child: _buildVmSection(),
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    title: 'Flutter image cache',
                    child: _buildFlutterSection(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRustSection() {
    final s = _rustSnapshot;
    if (s == null) {
      return const Text('No snapshot yet.');
    }
    return _MetricsTable(rows: [
      ('current_rss', _bytes(s.currentRss.toInt())),
      ('peak_rss', _bytes(s.peakRss.toInt())),
      ('current_commit', _bytes(s.currentCommit.toInt())),
      ('peak_commit', _bytes(s.peakCommit.toInt())),
      ('page_faults', s.pageFaults.toString()),
      ('elapsed_ms', s.elapsedMs.toString()),
      ('user_ms', s.userMs.toString()),
      ('system_ms', s.systemMs.toString()),
      ('ssh_sessions', s.sshSessions.toString()),
      ('ssh_connections', s.sshConnections.toString()),
      ('ssh_clients', s.sshClients.toString()),
      ('local_terminals', s.localTerminals.toString()),
      ('tunnel_configs', s.tunnelConfigs.toString()),
      ('tunnels_running', s.tunnelsRunning.toString()),
    ]);
  }

  Widget _buildDartSection() {
    return _MetricsTable(rows: [
      ('processCurrentRss', _bytes(_dartSnapshot.processCurrentRss)),
      ('processMaxRss', _bytes(_dartSnapshot.processMaxRss)),
    ]);
  }

  Widget _buildFlutterSection() {
    final f = _flutterSnapshot;
    return _MetricsTable(rows: [
      ('imageCacheCurrentSize', f.imageCacheCurrentSize.toString()),
      ('imageCacheCurrentBytes', _bytes(f.imageCacheCurrentBytes)),
      ('liveImageCount', f.liveImageCount.toString()),
      ('pendingImageCount', f.pendingImageCount.toString()),
      ('maximumSize', f.maximumSize.toString()),
      ('maximumSizeBytes', _bytes(f.maximumSizeBytes)),
    ]);
  }

  Widget _buildVmSection() {
    final v = _vmSnapshot;
    if (!v.connected) {
      return const Text(
        'VM service not connected — release builds disable it. Run with debug or profile to sample Dart heap.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricsTable(rows: [
          ('heapUsage', _bytes(v.heapUsage)),
          ('heapCapacity', _bytes(v.heapCapacity)),
          ('externalUsage', _bytes(v.externalUsage)),
        ]),
        const SizedBox(height: 12),
        Text(
          'Top classes by bytes',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        _MetricsTable(
          rows: [
            for (final c in v.topClasses)
              (c.className, '${_bytes(c.bytes)}  (${c.instances} instances)'),
          ],
        ),
      ],
    );
  }
}

String _bytes(int value) {
  if (value < 1024) return '$value B';
  if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KiB';
  if (value < 1024 * 1024 * 1024) {
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
  return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB';
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.background,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: () => onPressed(),
      child: Text(label),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0F0F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD6C7B8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricsTable extends StatelessWidget {
  const _MetricsTable({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (key, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: Text(
                    key,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B1D1D),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Snapshot error: $message',
        style: const TextStyle(color: Color(0xFFFFB280), fontSize: 12),
      ),
    );
  }
}

class _RssChartPainter extends CustomPainter {
  _RssChartPainter({required this.samples});

  final List<int> samples;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0A0B0B);
    canvas.drawRect(Offset.zero & size, bg);

    if (samples.length < 2) return;
    final minValue = samples.reduce((a, b) => a < b ? a : b);
    final maxValue = samples.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).clamp(1, 1 << 62);

    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = size.width * i / (samples.length - 1);
      final normalized = (samples[i] - minValue) / range;
      final y = size.height - normalized * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final stroke = Paint()
      ..color = const Color(0xFFFFB280)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _RssChartPainter oldDelegate) =>
      !_listEquals(oldDelegate.samples, samples);

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
