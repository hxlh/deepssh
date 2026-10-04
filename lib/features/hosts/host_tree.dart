import 'package:flutter/material.dart';

import '../../core/models/local_terminal_item.dart';
import '../../core/models/ssh_profile_item.dart';
import '../../core/models/ssh_session_item.dart';
import '../../core/models/terminal_item.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_spacing.dart';
import 'host_tree_node.dart';
import 'host_tree_state.dart';

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

  Widget _sessionItem(BuildContext context, SshSessionItem session) {
    final isSelected = selectedTerminalId == session.id;
    final groupColor = _groupColor(session.connectionGroupId);
    final iconColor = groupColor == Colors.transparent
        ? AppColors.textMuted
        : groupColor;
    final row = InkWell(
      onTap: () => onSshSessionTap(session),
      onSecondaryTapDown: (details) {
        _showSshSessionMenu(
          context: context,
          position: details.globalPosition,
          onEditNote: () => onEditSshSessionNote(session),
          onDuplicate: () => onDuplicateSshSession(session),
          onClose: () => onCloseSshSession(session),
        );
      },
      child: Container(
        height: AppSpacing.itemHeight,
        margin: compact
            ? const EdgeInsets.fromLTRB(4, 2, 4, 2)
            : const EdgeInsets.fromLTRB(24, 2, 8, 2),
        padding: compact
            ? EdgeInsets.zero
            : const EdgeInsets.only(left: 7, right: 10),
        decoration: BoxDecoration(
          // The 3px left rule carries connection state; a rounded fill would
          // fight the deck's zero-radius language.
          border: Border(
            left: BorderSide(
              color: isSelected ? groupColor : Colors.transparent,
              width: 3,
            ),
          ),
          color: isSelected
              ? DeckTokens.wash(groupColor, 0.30)
              : DeckTokens.wash(groupColor, 0.12),
        ),
        child: compact
            ? Center(
                child: Icon(
                  Icons.terminal,
                  size: 16,
                  color: isSelected ? AppColors.accentInk : iconColor,
                ),
              )
            : Row(
                children: [
                  Icon(
                    Icons.terminal,
                    size: 15,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.displayTitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
    return compact ? Tooltip(message: session.displayTitle, child: row) : row;
  }

  Widget _localTerminalItem(BuildContext context, LocalTerminalItem terminal) {
    final selected = selectedTerminalId == terminal.id;
    final row = InkWell(
      onTap: () => onLocalTerminalTap(terminal),
      onSecondaryTapDown: (details) {
        _showCloseMenu(
          context: context,
          position: details.globalPosition,
          label: '关闭终端',
          onClose: () => onCloseLocalTerminal(terminal),
        );
      },
      child: Container(
        height: AppSpacing.itemHeight,
        margin: compact
            ? const EdgeInsets.fromLTRB(4, 2, 4, 2)
            : const EdgeInsets.fromLTRB(24, 2, 8, 2),
        padding: compact
            ? EdgeInsets.zero
            : const EdgeInsets.only(left: 7, right: 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: selected ? AppColors.accent : Colors.transparent,
              width: 3,
            ),
          ),
          color: selected ? AppColors.selection : Colors.transparent,
        ),
        child: compact
            ? Center(
                child: Icon(
                  Icons.terminal,
                  size: 16,
                  color: selected ? AppColors.accentInk : AppColors.textMuted,
                ),
              )
            : Row(
                children: [
                  Icon(Icons.terminal, size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      terminal.displayTitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: selected
                            ? AppColors.accentInk
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
    return compact ? Tooltip(message: terminal.displayTitle, child: row) : row;
  }

  Widget _profileHeader(SshProfileItem profile) {
    final header = InkWell(
      onTap: () => onSshProfileTap(profile),
      child: Container(
        height: compact ? 34 : 32,
        margin: const EdgeInsets.fromLTRB(4, 2, 4, 2),
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
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: sessions.length,
            onReorder: (oldIndex, newIndex) {
              onReorderSessions?.call(profile.id, oldIndex, newIndex);
            },
            itemBuilder: (context, sessionIndex) {
              return ReorderableDragStartListener(
                index: sessionIndex,
                key: ValueKey('session-${sessions[sessionIndex].id}'),
                child: _sessionItem(context, sessions[sessionIndex]),
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
        margin: const EdgeInsets.fromLTRB(4, 2, 4, 2),
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
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: localTerminals.length,
            onReorder: onReorderLocalTerminals ?? (_, __) {},
            itemBuilder: (context, index) {
              return ReorderableDragStartListener(
                index: index,
                key: ValueKey('local-${localTerminals[index].id}'),
                child: _localTerminalItem(context, localTerminals[index]),
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
