import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_colors.dart';
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
    required this.onCollapsedChanged,
    required this.onHeightChanged,
  });

  final WorkbenchEvents events;
  final double height;
  final bool collapsed;

  /// Whether the 内存监控 panel takes part in the row. The Explorer's footer
  /// button owns this: with it off the panel *and* the inner splitter leave
  /// the row entirely, so 实时事件 fills the dock (prototype `data-mem`).
  final bool showMemory;

  /// Collapse/expand requests from the splitter, the fold arrow or the
  /// keyboard (`Home` / `End` / arrow keys).
  final ValueChanged<bool> onCollapsedChanged;

  /// Absolute panel height in logical pixels; the parent clamps it and expands
  /// the dock. The splitter maps the pointer position to this value directly,
  /// so the grip stays glued to the cursor across fold/unfold.
  final ValueChanged<double> onHeightChanged;

  @override
  State<WorkbenchDock> createState() => _WorkbenchDockState();
}

class _WorkbenchDockState extends State<WorkbenchDock> {
  static const double _collapsedHeight = 37;
  static const double _minHeight = 96;
  static const double _maxHeight = 420;
  static const double _collapseAt = 96;
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

  /// Bottom edge of the whole dock in global coordinates. The splitter uses it
  /// to turn the pointer's absolute Y into the panel height, matching the
  /// prototype's `dockHeightAt(clientY)`.
  double _dockBottomY() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return 0;
    return box.localToGlobal(Offset(0, box.size.height)).dy;
  }

  void _requestHeight(double height) {
    if (height < _collapseAt) {
      if (!widget.collapsed) widget.onCollapsedChanged(true);
      return;
    }
    if (widget.collapsed) widget.onCollapsedChanged(false);
    widget.onHeightChanged(height.clamp(_minHeight, _maxHeight));
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The splitter stays in the layout while folded: the prototype hides
        // only its grip, and dragging the strip back down re-opens the dock.
        _DockSplitter(
          collapsed: collapsed,
          currentHeight: collapsed ? _collapsedHeight : widget.height,
          dockBottomY: _dockBottomY,
          onHeightRequested: _requestHeight,
          onCollapseRequested: () => widget.onCollapsedChanged(true),
          onExpandRequested: (height) {
            widget.onCollapsedChanged(false);
            widget.onHeightChanged(height.clamp(_minHeight, _maxHeight));
          },
        ),
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
                      onToggle: () => widget.onCollapsedChanged(!collapsed),
                    ),
                  ),
                  if (showMemory) ...[
                    _VerticalGrip(
                      minWidth: _minEventsWidth,
                      maxWidth: widget.showMemory
                          ? math.max(
                              _minEventsWidth,
                              maxWidth - _minMemoryWidth,
                            )
                          : maxWidth,
                      currentWidth: eventsWidth,
                      onWidthRequested: (width) => setState(
                        () => _eventsWidth = width
                            .clamp(_minEventsWidth, maxWidth)
                            .toDouble(),
                      ),
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

/// Horizontal splitter above the dock: a real hit target in both states, with
/// the prototype's centred grip, hover accent and keyboard equivalents.
class _DockSplitter extends StatefulWidget {
  const _DockSplitter({
    required this.collapsed,
    required this.currentHeight,
    required this.dockBottomY,
    required this.onHeightRequested,
    required this.onCollapseRequested,
    required this.onExpandRequested,
  });

  final bool collapsed;
  final double currentHeight;
  final double Function() dockBottomY;
  final ValueChanged<double> onHeightRequested;
  final VoidCallback onCollapseRequested;
  final ValueChanged<double> onExpandRequested;

  static const double height = 10;

  @override
  State<_DockSplitter> createState() => _DockSplitterState();
}

class _DockSplitterState extends State<_DockSplitter> {
  static const double _minHeight = 96;
  static const double _maxHeight = 420;
  static const double _collapseAt = 96;
  static const double _collapsedHeight = 37;

  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;
  bool _dragging = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final current = widget.collapsed ? _collapsedHeight : widget.currentHeight;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final target = widget.collapsed
          ? _minHeight
          : (current + 16).clamp(_minHeight, _maxHeight);
      widget.onExpandRequested(target);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final target = current - 16;
      if (target < _collapseAt) {
        widget.onCollapseRequested();
      } else {
        widget.onHeightRequested(target);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      widget.onCollapseRequested();
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      widget.onExpandRequested(_maxHeight);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused || _dragging;
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _focusNode.requestFocus(),
          onVerticalDragStart: (_) {
            _focusNode.requestFocus();
            setState(() => _dragging = true);
          },
          onVerticalDragEnd: (_) => setState(() => _dragging = false),
          onVerticalDragCancel: () => setState(() => _dragging = false),
          onVerticalDragUpdate: (details) {
            final height =
                widget.dockBottomY() -
                details.globalPosition.dy -
                _DockSplitter.height / 2;
            widget.onHeightRequested(height);
          },
          child: SizedBox(
            height: _DockSplitter.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 1,
                    color: active ? AppColors.accent : AppColors.border,
                  ),
                ),
                if (!widget.collapsed)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 26,
                    height: 3,
                    color: active ? AppColors.textPrimary : AppColors.border,
                  ),
                if (active)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.14),
                              blurRadius: 0,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical splitter between the two dock panels.
class _VerticalGrip extends StatefulWidget {
  const _VerticalGrip({
    required this.minWidth,
    required this.maxWidth,
    required this.currentWidth,
    required this.onWidthRequested,
  });

  final double minWidth;
  final double maxWidth;
  final double currentWidth;
  final ValueChanged<double> onWidthRequested;

  static const double width = 7;

  @override
  State<_VerticalGrip> createState() => _VerticalGripState();
}

class _VerticalGripState extends State<_VerticalGrip> {
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;
  bool _dragging = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.onWidthRequested(widget.currentWidth - 16);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.onWidthRequested(widget.currentWidth + 16);
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      widget.onWidthRequested(widget.minWidth);
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      widget.onWidthRequested(widget.maxWidth);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused || _dragging;
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _focusNode.requestFocus(),
          onHorizontalDragStart: (_) {
            _focusNode.requestFocus();
            setState(() => _dragging = true);
          },
          onHorizontalDragEnd: (_) => setState(() => _dragging = false),
          onHorizontalDragCancel: () => setState(() => _dragging = false),
          onHorizontalDragUpdate: (details) =>
              widget.onWidthRequested(widget.currentWidth + details.delta.dx),
          child: SizedBox(
            width: _VerticalGrip.width,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 3,
                  child: Container(
                    width: 1,
                    color: active ? AppColors.accent : AppColors.border,
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 3,
                  height: 26,
                  color: active ? AppColors.textPrimary : AppColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
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
      // Folded, the title bar is the whole panel: the prototype drops the
      // outer bottom gap so 37px is enough for the header.
      margin: collapsed
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(0, 0, 0, 6),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.textPrimary),
        boxShadow: AppColors.shadowHard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              border: collapsed
                  ? null
                  : Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (onToggle != null)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onToggle,
                      child: Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 12,
                          color: AppColors.textMuted,
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
          ? Center(
              child: Text(
                '暂无事件',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
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
                    : AppColors.textPrimary,
              ),
            ),
          ),
        if (memory != null) ...[
          const SizedBox(width: 12),
          Text(
            'RSS ${_mb(memory!.currentRss)} MB',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: DeckTokens.fontMono,
              fontSize: 10.5,
              color: AppColors.textMuted,
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
        color: isError ? AppColors.dangerSoft : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              '$hh:$mm:$ss',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: DeckTokens.fontMono,
                fontSize: 10.5,
                color: AppColors.textMuted,
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
                : (isWarn ? DeckTokens.warn : AppColors.textMuted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
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
                      style: TextStyle(color: AppColors.accentInk),
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
          ? Center(
              child: Text(
                '等待采样',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _Gauge(
                  label: '常驻内存 (RSS)',
                  value: _mb(snapshot!.currentRss),
                  fraction: _fraction(snapshot!.currentRss, snapshot!.peakRss),
                  color: AppColors.accent,
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
                  color: AppColors.textPrimary,
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
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: DeckTokens.fontMono,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.border,
              border: Border.all(color: AppColors.border),
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
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: DeckTokens.fontMono,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
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
