import 'package:flutter/material.dart';

import '../../core/models/local_terminal_item.dart';
import '../../core/models/ssh_profile_item.dart';
import '../../core/models/ssh_session_item.dart';
import '../../core/models/terminal_item.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'host_tree_node.dart';
import 'host_tree_state.dart';
import 'session_reorder.dart';

class HostTree extends StatelessWidget {
  const HostTree({
    super.key,
    required this.state,
    required this.selectedTerminalId,
    required this.onToggleHost,
    required this.onTerminalTap,
    required this.localTerminals,
    required this.localExpanded,
    required this.onToggleLocal,
    required this.onLocalTerminalTap,
    required this.sshProfiles,
    required this.sshSessionsByProfileId,
    required this.onSshProfileTap,
    required this.onSshSessionTap,
    required this.onEditSshSessionNote,
    required this.onCloseSshSession,
    required this.onDuplicateSshSession,
    required this.onCloseLocalTerminal,
    required this.onOpenThemeConfig,
    required this.themeConfigActive,
    required this.onToggleMemoryDock,
    required this.memoryDockVisible,
    this.onReorderSessions,
    this.onReorderLocalTerminals,
    this.sectionOrder = const [],
    this.onSectionOrderChanged,
    this.compact = false,
  });

  final HostTreeState state;
  final String? selectedTerminalId;
  final ValueChanged<String> onToggleHost;
  final ValueChanged<TerminalItem> onTerminalTap;
  final List<LocalTerminalItem> localTerminals;
  final bool localExpanded;
  final VoidCallback onToggleLocal;
  final ValueChanged<LocalTerminalItem> onLocalTerminalTap;
  final List<SshProfileItem> sshProfiles;
  final Map<String, List<SshSessionItem>> sshSessionsByProfileId;
  final ValueChanged<SshProfileItem> onSshProfileTap;
  final ValueChanged<SshSessionItem> onSshSessionTap;
  final Future<void> Function(SshSessionItem) onEditSshSessionNote;
  final Future<void> Function(SshSessionItem) onCloseSshSession;
  final Future<void> Function(SshSessionItem) onDuplicateSshSession;
  final Future<void> Function(LocalTerminalItem) onCloseLocalTerminal;
  final VoidCallback onOpenThemeConfig;
  final bool themeConfigActive;

  /// Shows/hides the dock's 内存监控 panel (prototype `exMemToggle`).
  final VoidCallback onToggleMemoryDock;
  final bool memoryDockVisible;
  final void Function(String profileId, int oldIndex, int newIndex)?
  onReorderSessions;
  final void Function(int oldIndex, int newIndex)? onReorderLocalTerminals;
  final List<String> sectionOrder;
  final ValueChanged<List<String>>? onSectionOrderChanged;

  /// Icon-rail mode (prototype `RAIL_MAX`, width <= 96px): names leave the
  /// painted box but stay available through tooltips, and the group identity
  /// rides the icon colour and the active row's left rule.
  final bool compact;

  /// Read through a getter so it follows the live theme.
  static Color get _menuAccent => AppColors.accent;
  static const double _menuItemHeight = 32;
  static const double _menuWidth = 150;
  static const String _localSectionId = 'local';

  // Geometry mirrored from .ex-scroll/.ex-ghead/.ex-row in the HTML
  // prototype. Keeping these values here makes screenshot comparisons useful.
  static const double _rowHeight = 32;
  static const double _rowLeft = 24;
  static const double _rowRight = 8;
  static const double _rowGap = 2;
  static const SessionRowMetrics _rowMetrics = SessionRowMetrics(
    rowHeight: _rowHeight,
    rowGap: _rowGap,
    rowLeft: _rowLeft,
    rowRight: _rowRight,
  );

  static Widget _dragProxy(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.panel),
        child: child,
      ),
    );
  }

  Color _groupColor(String connectionGroupId) {
    if (connectionGroupId.isEmpty) return Colors.transparent;
    final hash = connectionGroupId.hashCode.abs();
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.70, 0.45).toColor();
  }

  String _profileSectionId(String profileId) => 'profile:$profileId';

  String? _profileIdFromSectionId(String sectionId) {
    const prefix = 'profile:';
    if (!sectionId.startsWith(prefix)) return null;
    return sectionId.substring(prefix.length);
  }

  List<String> _sectionIds() {
    final available = [
      for (final profile in sshProfiles) _profileSectionId(profile.id),
      if (localTerminals.isNotEmpty) _localSectionId,
    ];
    return [
      for (final id in sectionOrder)
        if (available.contains(id)) id,
      for (final id in available)
        if (!sectionOrder.contains(id)) id,
    ];
  }

  void _handleSectionReorder(int oldIndex, int newIndex) {
    final next = _sectionIds();
    final item = next.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    next.insert(insertAt, item);
    onSectionOrderChanged?.call(next);
  }

  RelativeRect _menuPosition(BuildContext context, Offset position) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    );
  }

  Future<String?> _showStyledMenu({
    required BuildContext context,
    required Offset position,
    required List<PopupMenuEntry<String>> items,
  }) {
    return showMenu<String>(
      context: context,
      position: _menuPosition(context, position),
      color: AppColors.panel,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      menuPadding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: _menuWidth),
      clipBehavior: Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.textPrimary),
      ),
      items: items,
    );
  }

  Future<void> _showCloseMenu({
    required BuildContext context,
    required Offset position,
    required String label,
    required Future<void> Function() onClose,
  }) async {
    final selected = await _showStyledMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'close',
          height: _menuItemHeight,
          padding: EdgeInsets.zero,
          child: _HostContextMenuItem(label: label),
        ),
      ],
    );
    if (selected == 'close') {
      await onClose();
    }
  }

  Future<void> _showSshSessionMenu({
    required BuildContext context,
    required Offset position,
    required Future<void> Function() onEditNote,
    required Future<void> Function() onDuplicate,
    required Future<void> Function() onClose,
  }) async {
    final selected = await _showStyledMenu(
      context: context,
      position: position,
      items: const [
        PopupMenuItem<String>(
          value: 'edit-note',
          height: _menuItemHeight,
          padding: EdgeInsets.zero,
          child: _HostContextMenuItem(label: '编辑备注'),
        ),
        PopupMenuItem<String>(
          value: 'duplicate',
          height: _menuItemHeight,
          padding: EdgeInsets.zero,
          child: _HostContextMenuItem(label: '复制'),
        ),
        PopupMenuItem<String>(
          value: 'close',
          height: _menuItemHeight,
          padding: EdgeInsets.zero,
          child: _HostContextMenuItem(label: '关闭 SSH 会话'),
        ),
      ],
    );
    switch (selected) {
      case 'edit-note':
        await onEditNote();
        break;
      case 'duplicate':
        await onDuplicate();
        break;
      case 'close':
        await onClose();
        break;
    }
  }

  Widget _sessionItem(
    BuildContext context,
    SshSessionItem session, {
    Key? key,
    required int reorderIndex,
    SessionReorderController? dragController,
  }) {
    return _ExplorerSessionRow(
      key: key,
      reorderIndex: reorderIndex,
      dragController: dragController,
      compact: compact,
      selected: selectedTerminalId == session.id,
      accentColor: _groupColor(session.connectionGroupId),
      icon: Icons.terminal,
      label: session.displayTitle,
      closeTooltip: '关闭 SSH 会话',
      onTap: () => onSshSessionTap(session),
      onClose: () => onCloseSshSession(session),
      onSecondaryTapDown: (details) {
        _showSshSessionMenu(
          context: context,
          position: details.globalPosition,
          onEditNote: () => onEditSshSessionNote(session),
          onDuplicate: () => onDuplicateSshSession(session),
          onClose: () => onCloseSshSession(session),
        );
      },
    );
  }

  Widget _localTerminalItem(
    BuildContext context,
    LocalTerminalItem terminal, {
    Key? key,
    required int reorderIndex,
    SessionReorderController? dragController,
  }) {
    return _ExplorerSessionRow(
      key: key,
      reorderIndex: reorderIndex,
      dragController: dragController,
      compact: compact,
      selected: selectedTerminalId == terminal.id,
      accentColor: AppColors.accent,
      local: true,
      icon: Icons.terminal,
      label: terminal.displayTitle,
      closeTooltip: '关闭终端',
      onTap: () => onLocalTerminalTap(terminal),
      onClose: () => onCloseLocalTerminal(terminal),
      onSecondaryTapDown: (details) {
        _showCloseMenu(
          context: context,
          position: details.globalPosition,
          label: '关闭终端',
          onClose: () => onCloseLocalTerminal(terminal),
        );
      },
    );
  }

  Widget _profileHeader(SshProfileItem profile) {
    final header = InkWell(
      onTap: () => onSshProfileTap(profile),
      child: Container(
        height: compact ? 34 : 32,
        margin: const EdgeInsets.symmetric(vertical: _rowGap),
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: _groupColor(profile.id), width: 3),
          ),
        ),
        child: compact
            ? Center(
                child: Icon(
                  Icons.computer,
                  size: 16,
                  color: _groupColor(profile.id),
                ),
              )
            : Row(
                children: [
                  Icon(Icons.computer, size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profile.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
    return compact ? Tooltip(message: profile.name, child: header) : header;
  }

  Widget _profileSection(SshProfileItem profile, int sectionIndex) {
    final sessions =
        sshSessionsByProfileId[profile.id] ?? const <SshSessionItem>[];
    return Column(
      key: ValueKey('section-profile-${profile.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableDragStartListener(
          index: sectionIndex,
          child: _profileHeader(profile),
        ),
        if (sessions.isNotEmpty)
          SessionReorderList(
            itemCount: sessions.length,
            metrics: _rowMetrics,
            onReorder: (oldIndex, newIndex) {
              onReorderSessions?.call(profile.id, oldIndex, newIndex);
            },
            itemBuilder: (context, sessionIndex, dragController) {
              final session = sessions[sessionIndex];
              return _sessionItem(
                context,
                session,
                key: ValueKey('session-${session.id}'),
                reorderIndex: sessionIndex,
                dragController: dragController,
              );
            },
          ),
      ],
    );
  }

  Widget _localSection(int sectionIndex) {
    final header = InkWell(
      onTap: onToggleLocal,
      child: Container(
        height: compact ? 34 : 32,
        margin: const EdgeInsets.symmetric(vertical: _rowGap),
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
        ),
        child: compact
            ? Center(
                child: Icon(
                  Icons.laptop,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              )
            : Row(
                children: [
                  Icon(Icons.laptop, size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Local',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    localExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
      ),
    );
    return Column(
      key: const ValueKey('section-local'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableDragStartListener(
          index: sectionIndex,
          child: compact ? Tooltip(message: 'Local', child: header) : header,
        ),
        if (localExpanded)
          SessionReorderList(
            itemCount: localTerminals.length,
            metrics: _rowMetrics,
            onReorder: onReorderLocalTerminals ?? (_, __) {},
            itemBuilder: (context, index, dragController) {
              final terminal = localTerminals[index];
              return _localTerminalItem(
                context,
                terminal,
                key: ValueKey('local-${terminal.id}'),
                reorderIndex: index,
                dragController: dragController,
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sectionIds();
    final profilesById = {
      for (final profile in sshProfiles) profile.id: profile,
    };
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sshProfiles.isEmpty)
                  ...state.hosts.map((host) {
                    return HostTreeNode(
                      host: host,
                      expanded: state.isExpanded(host.id),
                      selectedTerminalId: selectedTerminalId,
                      onToggle: () => onToggleHost(host.id),
                      onTerminalTap: onTerminalTap,
                    );
                  }),
                if (sections.isNotEmpty)
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    proxyDecorator: _dragProxy,
                    itemCount: sections.length,
                    onReorder: _handleSectionReorder,
                    itemBuilder: (context, sectionIndex) {
                      final sectionId = sections[sectionIndex];
                      if (sectionId == _localSectionId) {
                        return _localSection(sectionIndex);
                      }
                      final profileId = _profileIdFromSectionId(sectionId)!;
                      return _profileSection(
                        profilesById[profileId]!,
                        sectionIndex,
                      );
                    },
                  ),
                if (sections.isEmpty && state.hosts.isEmpty)
                  _TreeEmptyState(compact: compact),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
          child: Column(
            children: [
              _FooterTool(
                label: '主题配置',
                icon: Icons.palette_outlined,
                active: themeConfigActive,
                tooltip: '主题配置',
                compact: compact,
                onTap: onOpenThemeConfig,
              ),
              _FooterTool(
                label: '内存监控',
                icon: Icons.memory,
                active: memoryDockVisible,
                tooltip: memoryDockVisible ? '隐藏内存监控面板' : '显示内存监控面板',
                compact: compact,
                onTap: onToggleMemoryDock,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HostContextMenuItem extends StatefulWidget {
  const _HostContextMenuItem({required this.label});

  final String label;

  @override
  State<_HostContextMenuItem> createState() => _HostContextMenuItemState();
}

class _HostContextMenuItemState extends State<_HostContextMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        width: HostTree._menuWidth,
        height: HostTree._menuItemHeight,
        color: _hovered ? AppColors.fgSoft : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 3,
              height: double.infinity,
              color: _hovered ? HostTree._menuAccent : Colors.transparent,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: _hovered ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Session/local-terminal row matching the prototype's `.ex-row`: a 14px drag
/// grip, the 15px type icon, the name and a close button that fades in on
/// hover (or keyboard focus).
class _ExplorerSessionRow extends StatefulWidget {
  const _ExplorerSessionRow({
    super.key,
    required this.reorderIndex,
    this.dragController,
    required this.compact,
    required this.selected,
    required this.accentColor,
    required this.icon,
    this.local = false,
    required this.label,
    required this.closeTooltip,
    required this.onTap,
    required this.onClose,
    this.onSecondaryTapDown,
  });

  final int reorderIndex;
  final SessionReorderController? dragController;
  final bool compact;
  final bool selected;
  final Color accentColor;
  final IconData icon;

  /// Local terminals follow `.ex-row.local`: no wash at rest, `--accent-soft`
  /// plus `--accent-ink` copy when active, and `--fg` glyphs in the rail.
  /// SSH rows carry their group wash instead.
  final bool local;
  final String label;
  final String closeTooltip;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final GestureTapDownCallback? onSecondaryTapDown;

  @override
  State<_ExplorerSessionRow> createState() => _ExplorerSessionRowState();
}

class _ExplorerSessionRowState extends State<_ExplorerSessionRow> {
  bool _hovered = false;
  bool _closeFocused = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final groupColor = widget.accentColor;
    // `.ex-row .ico` is muted in the expanded layout; the group colours only
    // move onto the glyphs in the <=96px rail (container query).
    final iconColor = widget.compact
        ? (widget.local ? AppColors.textPrimary : groupColor)
        : AppColors.textMuted;
    final background = widget.local
        ? (selected ? AppColors.selection : Colors.transparent)
        : DeckTokens.wash(groupColor, selected ? 0.30 : 0.12);
    final nameColor = widget.local && selected
        ? AppColors.accentInk
        : AppColors.textPrimary;
    if (widget.compact) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: widget.onTap,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          child: Container(
            height: HostTree._rowHeight,
            margin: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: selected ? groupColor : Colors.transparent,
                  width: 3,
                ),
              ),
              color: background,
            ),
            child: Center(
              child: Tooltip(
                message: widget.label,
                child: Icon(
                  widget.icon,
                  size: 16,
                  color: selected ? AppColors.accentInk : iconColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget content = Stack(
      clipBehavior: Clip.none,
      children: [
        // The prototype lifts the row from a press anywhere on it — the
        // grip is the affordance, not the only drag surface. The close
        // button sits above this surface in the stack, and stack hits
        // stop at the topmost child, so a press that starts on the button
        // never starts a reorder.
        Positioned(
          left: HostTree._rowLeft,
          right: HostTree._rowRight,
          top: HostTree._rowGap,
          bottom: HostTree._rowGap,
          child: RowDragSurface(
            index: widget.reorderIndex,
            controller: widget.dragController,
            child: InkWell(
              onTap: widget.onTap,
              onSecondaryTapDown: widget.onSecondaryTapDown,
              child: Container(
                height: HostTree._rowHeight,
                // The 26px right padding reserves the 22px close slot
                // (plus the row's 4px end padding) so the name still
                // ellipsises exactly where it did when the button sat
                // in the row's own flex.
                padding: const EdgeInsets.fromLTRB(10, 0, 26, 0),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: selected ? groupColor : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  color: background,
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 15, color: iconColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: nameColor,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Close button: above the drag surface, so presses land here
        // only, and the row's own flex no longer needs to make room.
        Positioned(
          right: HostTree._rowRight + 4,
          top: HostTree._rowGap + 5,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: _hovered || _closeFocused ? 1 : 0,
            child: Tooltip(
              message: widget.closeTooltip,
              child: GestureDetector(
                onTap: widget.onClose,
                onSecondaryTapDown: widget.onSecondaryTapDown,
                child: Focus(
                  onFocusChange: (focused) =>
                      setState(() => _closeFocused = focused),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Icon(
                      Icons.close,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // The grip is painted in the row's left gutter, so it has to be a
        // child of this full-width stack. The previous layout parked it
        // at `Positioned(left: -24)` inside the inset row stack: that
        // renders through `Clip.none` but stacks never hit-test outside
        // their own bounds, so pointer events never reached it and the
        // rows could not be dragged at all.
        Positioned(
          left: HostTree._rowLeft - 11,
          top: HostTree._rowGap + 5,
          child: RowDragSurface(
            index: widget.reorderIndex,
            controller: widget.dragController,
            cursor: SystemMouseCursors.grab,
            child: SizedBox(
              width: 14,
              height: 22,
              child: Icon(
                Icons.drag_indicator,
                size: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
    final SessionReorderController? dragController = widget.dragController;
    if (dragController != null) {
      content = ValueListenableBuilder<int?>(
        valueListenable: dragController.dragging,
        builder: (context, draggingIndex, child) => Opacity(
          // The lifted row flies in the overlay; its slot stays empty.
          opacity: draggingIndex == widget.reorderIndex ? 0 : 1,
          child: child,
        ),
        child: content,
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        height: HostTree._rowHeight + HostTree._rowGap * 2,
        child: content,
      ),
    );
  }
}

/// Tree empty state: `#exTreeEmpty`. The rail keeps the icon and drops the
/// copy so a 56px column never shows clipped text.
class _TreeEmptyState extends StatelessWidget {
  const _TreeEmptyState({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 28),
      child: Column(
        children: [
          Icon(Icons.terminal, size: 26, color: AppColors.textMuted),
          if (!compact) ...[
            const SizedBox(height: 10),
            Text(
              '暂无已打开的会话',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: DeckTokens.fontMono,
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '从右上角「新增连接」打开一个终端',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Explorer footer tool row, matching the prototype's `.ex-foot` / `.ex-tool`.
class _FooterTool extends StatefulWidget {
  const _FooterTool({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.tooltip,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String? tooltip;
  final bool compact;

  @override
  State<_FooterTool> createState() => _FooterToolState();
}

class _FooterToolState extends State<_FooterTool> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.active
        ? AppColors.accentSoft
        : (_hovered ? AppColors.fgSoft : Colors.transparent);
    final foreground = widget.active
        ? AppColors.accentInk
        : AppColors.textMuted;
    final body = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: widget.compact ? 34 : 32,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 0 : 8),
          color: background,
          child: widget.compact
              ? Center(child: Icon(widget.icon, size: 15, color: foreground))
              : Row(
                  children: [
                    Icon(widget.icon, size: 14, color: foreground),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: foreground,
                        fontWeight: widget.active
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
    final tip = widget.compact
        ? (widget.tooltip ?? widget.label)
        : widget.tooltip;
    return tip == null ? body : Tooltip(message: tip, child: body);
  }
}
