import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/deck_widgets.dart';
import '../../src/rust/mem_metrics.dart';
import '../events/workbench_events.dart';

/// Bottom dock: a live event feed on the left and process memory on the right,
/// split by a draggable divider and collapsible to a 37px title bar.
class WorkbenchDock extends StatefulWidget {
  const WorkbenchDock({
    super.key,
    required this.events,
    required this.height,
    required this.collapsed,
    required this.showMemory,
    required this.onToggleCollapsed,
    required this.onHeightChanged,
  });

  final WorkbenchEvents events;
  final double height;
  final bool collapsed;

  /// Whether the 内存监控 panel takes part in the row. The Explorer's footer
  /// button owns this: with it off the panel *and* the inner splitter leave
  /// the row entirely, so 实时事件 fills the dock (prototype `data-mem`).
  final bool showMemory;

  final VoidCallback onToggleCollapsed;
  final ValueChanged<double> onHeightChanged;

  @override
  State<WorkbenchDock> createState() => _WorkbenchDockState();
}

class _WorkbenchDockState extends State<WorkbenchDock> {
  static const double _collapsedHeight = 37;
  static const double _eventsFraction = 0.6;
  static const double _minEventsWidth = 260;
  static const double _minMemoryWidth = 220;
  static const Duration _pollInterval = Duration(seconds: 2);

  RustMemSnapshot? _snapshot;
  Timer? _poll;

  /// Null until the user drags the divider, so the first layout uses the
  /// default fraction.
  double? _eventsWidth;

  @override
  void initState() {
    super.initState();
    widget.events.addListener(_onEventsChanged);
    unawaited(_refreshMemory());
    _poll = Timer.periodic(_pollInterval, (_) => _refreshMemory());
  }

  @override
  void dispose() {
    _poll?.cancel();
    widget.events.removeListener(_onEventsChanged);
    super.dispose();
  }

  void _onEventsChanged() {
    if (mounted) setState(() {});
  }

  /// Samples the native allocator counters.
  ///
  /// Any failure (Rust not initialised, platform unsupported) leaves the
  /// previous reading in place. That also keeps widget tests quiet: with no
  /// data there is no `setState`, so no frames are scheduled and
  /// `pumpAndSettle` can finish.
  Future<void> _refreshMemory() async {
    late final RustMemSnapshot next;
    try {
      next = await rustMemSnapshot();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final previous = _snapshot;
    if (previous != null &&
        previous.currentRss == next.currentRss &&
        previous.peakRss == next.peakRss &&
        previous.currentCommit == next.currentCommit &&
        previous.sshSessions == next.sshSessions &&
        previous.tunnelsRunning == next.tunnelsRunning) {
      return;
    }
    setState(() => _snapshot = next);
  }

  void _dragEventsWidth(DragUpdateDetails details, double maxWidth) {
    final current = _eventsWidth ?? maxWidth * _eventsFraction;
    // With 内存监控 hidden there is no second panel to make room for, so the
    // divider can push the feed all the way across.
    final upper = widget.showMemory
        ? (maxWidth - _minMemoryWidth).clamp(_minEventsWidth, 900.0)
        : maxWidth;
    setState(
      () => _eventsWidth = (current + details.delta.dx).clamp(
        _minEventsWidth,
        upper,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!collapsed) _HorizontalGrip(onDrag: widget.onHeightChanged),
        SizedBox(
          height: collapsed ? _collapsedHeight : widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final showMemory = widget.showMemory && !collapsed;
              final eventsWidth = collapsed || !showMemory
                  ? maxWidth
                  : (_eventsWidth ?? maxWidth * _eventsFraction).clamp(
                      0.0,
                      maxWidth,
                    );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: eventsWidth,
                    child: _EventsPanel(
                      events: widget.events,
                      collapsed: collapsed,
                      memory: _snapshot,
                      onToggle: widget.onToggleCollapsed,
                    ),
                  ),
                  if (showMemory) ...[
                    _VerticalGrip(
                      onDrag: (details) => _dragEventsWidth(details, maxWidth),
                    ),
                    Expanded(child: _MemoryPanel(snapshot: _snapshot)),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Horizontal splitter above the dock.
class _HorizontalGrip extends StatelessWidget {
  const _HorizontalGrip({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
      child: Container(
        height: 7,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: DeckTokens.border)),
        ),
      ),
    );
  }
}

/// Vertical splitter between the two dock panels.
class _VerticalGrip extends StatelessWidget {
  const _VerticalGrip({required this.onDrag});

  final ValueChanged<DragUpdateDetails> onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: onDrag,
      child: Container(width: 7),
    );
  }
}

class _DockPanelShell extends StatelessWidget {
  const _DockPanelShell({
    required this.label,
    required this.collapsed,
    required this.trailing,
    required this.child,
    this.onToggle,
  });

  final String label;
  final bool collapsed;
  final Widget trailing;
  final Widget child;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 6),
      decoration: BoxDecoration(
        color: DeckTokens.surface,
        border: Border.all(color: DeckTokens.fg),
        boxShadow: DeckTokens.shadowHard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              border: collapsed
                  ? null
                  : const Border(bottom: BorderSide(color: DeckTokens.border)),
            ),
            child: Row(
              children: [
                if (onToggle != null)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onToggle,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 12,
                          color: DeckTokens.muted,
                        ),
                      ),
                    ),
                  ),
                DeckLabel(label, size: 10.5),
                const Spacer(),
                trailing,
              ],
            ),
          ),
          if (!collapsed) Expanded(child: child),
        ],
      ),
    );
  }
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({
    required this.events,
    required this.collapsed,
    required this.memory,
    required this.onToggle,
  });

  final WorkbenchEvents events;
  final bool collapsed;
  final RustMemSnapshot? memory;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final entries = events.entries;
    return _DockPanelShell(
      label: '实时事件',
      collapsed: collapsed,
      onToggle: onToggle,
      // Folded, the title bar still reports the newest entry.
      trailing: collapsed
          ? _MiniSummary(entries: entries, memory: memory)
          : DeckLabel('${entries.length}', size: 10),
      child: entries.isEmpty
          ? const Center(
              child: Text(
                '暂无事件',
                style: TextStyle(fontSize: 11.5, color: DeckTokens.muted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: entries.length,
              itemBuilder: (context, index) => _FeedRow(event: entries[index]),
            ),
    );
  }
}

class _MiniSummary extends StatelessWidget {
  const _MiniSummary({required this.entries, required this.memory});

  final List<WorkbenchEvent> entries;
  final RustMemSnapshot? memory;

  @override
  Widget build(BuildContext context) {
    final latest = entries.isEmpty ? null : entries.first;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (latest != null)
          Flexible(
            child: Text(
              latest.message,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: DeckTokens.fontMono,
                fontSize: 10.5,
                color: latest.level == WorkbenchEventLevel.error
                    ? DeckTokens.danger
                    : DeckTokens.fg,
              ),
            ),
          ),
        if (memory != null) ...[
          const SizedBox(width: 12),
          Text(
            'RSS ${_mb(memory!.currentRss)} MB',
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: DeckTokens.fontMono,
              fontSize: 10.5,
              color: DeckTokens.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.event});

  final WorkbenchEvent event;

  @override
  Widget build(BuildContext context) {
    final isError = event.level == WorkbenchEventLevel.error;
    final isWarn = event.level == WorkbenchEventLevel.warn;
    final hh = event.time.hour.toString().padLeft(2, '0');
    final mm = event.time.minute.toString().padLeft(2, '0');
    final ss = event.time.second.toString().padLeft(2, '0');

    return Container(
      padding: EdgeInsets.fromLTRB(isError ? 9 : 12, 6, 12, 6),
      decoration: BoxDecoration(
        // Severity rides a 3px left rule, not a separate panel. An outer
        // BoxShadow would flood the whole row instead.
        border: isError
            ? const Border(left: BorderSide(color: DeckTokens.danger, width: 3))
            : null,
        color: isError ? DeckTokens.dangerSoft : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              '$hh:$mm:$ss',
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: DeckTokens.fontMono,
                fontSize: 10.5,
                color: DeckTokens.muted,
              ),
            ),
          ),
          Icon(
            isError || isWarn
                ? Icons.warning_amber_rounded
                : Icons.chevron_right,
            size: 14,
            color: isError
                ? DeckTokens.danger
                : (isWarn ? DeckTokens.warn : DeckTokens.muted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: DeckTokens.fg),
                children: [
                  if (isError || isWarn) ...[
                    TextSpan(
                      text: isError ? 'ERROR  ' : 'WARN  ',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontFamilyFallback: DeckTokens.fontMono,
                        fontSize: 9.5,
                        letterSpacing: 0.1,
                        color: isError ? DeckTokens.danger : DeckTokens.warn,
                      ),
                    ),
                  ],
                  TextSpan(text: event.message),
                  if (event.subject != null)
                    TextSpan(
                      text: '  ${event.subject}',
                      style: TextStyle(color: DeckTokens.accentInk),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryPanel extends StatelessWidget {
  const _MemoryPanel({required this.snapshot});

  final RustMemSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    return _DockPanelShell(
      label: '内存监控',
      collapsed: false,
      trailing: snapshot == null
          ? DeckLabel('—', size: 10)
          : DeckLabel('RSS ${_mb(snapshot!.currentRss)} MB', size: 10),
      child: snapshot == null
          ? const Center(
              child: Text(
                '等待采样',
                style: TextStyle(fontSize: 11.5, color: DeckTokens.muted),
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _Gauge(
                  label: '常驻内存 (RSS)',
                  value: _mb(snapshot!.currentRss),
                  fraction: _fraction(snapshot!.currentRss, snapshot!.peakRss),
                  color: DeckTokens.accent,
                ),
                _Gauge(
                  label: '峰值内存',
                  value: _mb(snapshot!.peakRss),
                  fraction: 1,
                  color: DeckTokens.ok,
                ),
                _Gauge(
                  label: '提交内存 (Commit)',
                  value: _mb(snapshot!.currentCommit),
                  fraction: _fraction(
                    snapshot!.currentCommit,
                    snapshot!.peakCommit,
                  ),
                  color: DeckTokens.fg,
                ),
                _KeyValue(label: '页错误', value: '${snapshot!.pageFaults}'),
                _KeyValue(
                  label: 'SSH 会话',
                  value:
                      '${snapshot!.sshSessions} / ${snapshot!.sshConnections}',
                ),
                _KeyValue(label: '本地终端', value: '${snapshot!.localTerminals}'),
                _KeyValue(
                  label: '隧道',
                  value:
                      '${snapshot!.tunnelsRunning} / ${snapshot!.tunnelConfigs}',
                ),
              ],
            ),
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  final String label;
  final String value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DeckTokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: DeckTokens.muted),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: DeckTokens.fontMono,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DeckTokens.fg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: DeckTokens.border,
              border: Border.all(color: DeckTokens.border),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: DeckTokens.muted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: DeckTokens.fontMono,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: DeckTokens.fg,
            ),
          ),
        ],
      ),
    );
  }
}

String _mb(BigInt bytes) =>
    (bytes.toDouble() / (1024 * 1024)).toStringAsFixed(1);

double _fraction(BigInt value, BigInt max) {
  final v = value.toDouble();
  final m = max.toDouble();
  if (m <= 0) return 0;
  return v / m;
}
