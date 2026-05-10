import 'package:flutter/material.dart';

import '../../core/models/local_terminal_item.dart';
import '../../core/models/ssh_profile_item.dart';
import '../../core/models/ssh_session_item.dart';
import '../../core/models/terminal_item.dart';
import '../../core/theme/app_colors.dart';
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
    required this.onOpenDiagnostics,
    required this.diagnosticsActive,
    this.onReorderSessions,
    this.onReorderLocalTerminals,
    this.sectionOrder = const [],
    this.onSectionOrderChanged,
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
  final VoidCallback onOpenDiagnostics;
  final bool diagnosticsActive;
  final void Function(String profileId, int oldIndex, int newIndex)?
  onReorderSessions;
  final void Function(int oldIndex, int newIndex)? onReorderLocalTerminals;
  final List<String> sectionOrder;
  final ValueChanged<List<String>>? onSectionOrderChanged;

  static const Color _menuAccent = Color(0xFFFFB280);
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
      elevation: 8,
      shadowColor: const Color(0x66000000),
      surfaceTintColor: Colors.transparent,
      menuPadding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: _menuWidth),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: AppColors.border),
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
    return InkWell(
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
        margin: const EdgeInsets.fromLTRB(24, 2, 8, 2),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? groupColor.withOpacity(0.30)
              : groupColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Row(
          children: [
            Icon(Icons.terminal, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                session.displayTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _localTerminalItem(BuildContext context, LocalTerminalItem terminal) {
    return InkWell(
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
        margin: const EdgeInsets.fromLTRB(24, 2, 8, 2),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selectedTerminalId == terminal.id
              ? AppColors.selection
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Row(
          children: [
            Icon(Icons.terminal, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(terminal.title, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileHeader(SshProfileItem profile) {
    return InkWell(
      onTap: () => onSshProfileTap(profile),
      child: Container(
        height: AppSpacing.itemHeight,
        margin: const EdgeInsets.fromLTRB(8, 2, 8, 2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icon(Icons.computer, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(profile.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
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
    return Column(
      key: const ValueKey('section-local'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableDragStartListener(
          index: sectionIndex,
          child: InkWell(
            onTap: onToggleLocal,
            child: Container(
              height: AppSpacing.itemHeight,
              margin: const EdgeInsets.fromLTRB(8, 2, 8, 2),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.laptop, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Local')),
                  Icon(
                    localExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
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
              ],
            ),
          ),
        ),
        _DiagnosticsButton(
          active: diagnosticsActive,
          onTap: onOpenDiagnostics,
        ),
        _ThemeConfigButton(active: themeConfigActive, onTap: onOpenThemeConfig),
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
        color: _hovered ? AppColors.tabHover : Colors.transparent,
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

class _ThemeConfigButton extends StatefulWidget {
  const _ThemeConfigButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  State<_ThemeConfigButton> createState() => _ThemeConfigButtonState();
}

class _ThemeConfigButtonState extends State<_ThemeConfigButton> {
  bool hovered = false;

  static const Color _activeBg = Color(0xFF592E17);
  static const Color _activeBorder = Color(0xFFFFB280);
  static const Color _activeText = Color(0xFFFFF2D9);
  static const Color _hoverBg = Color(0xFF1A1B1C);
  static const Color _hoverBorder = Color(0xFF3A3A3A);

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final Color bg = active
        ? _activeBg
        : (hovered ? _hoverBg : Colors.transparent);
    final Color borderColor = active
        ? _activeBorder
        : (hovered ? _hoverBorder : Colors.transparent);
    final Color foreground = active ? _activeText : AppColors.textMuted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: AppSpacing.itemHeight,
          margin: const EdgeInsets.fromLTRB(8, 2, 8, 8),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.settings, size: 16, color: foreground),
              const SizedBox(width: 8),
              Text(
                '主题配置',
                style: TextStyle(
                  color: foreground,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsButton extends StatefulWidget {
  const _DiagnosticsButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  State<_DiagnosticsButton> createState() => _DiagnosticsButtonState();
}

class _DiagnosticsButtonState extends State<_DiagnosticsButton> {
  bool hovered = false;

  static const Color _activeBg = Color(0xFF592E17);
  static const Color _activeBorder = Color(0xFFFFB280);
  static const Color _activeText = Color(0xFFFFF2D9);
  static const Color _hoverBg = Color(0xFF1A1B1C);
  static const Color _hoverBorder = Color(0xFF3A3A3A);

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final Color bg = active
        ? _activeBg
        : (hovered ? _hoverBg : Colors.transparent);
    final Color borderColor = active
        ? _activeBorder
        : (hovered ? _hoverBorder : Colors.transparent);
    final Color foreground = active ? _activeText : AppColors.textMuted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: AppSpacing.itemHeight,
          margin: const EdgeInsets.fromLTRB(8, 2, 8, 2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.memory, size: 16, color: foreground),
              const SizedBox(width: 8),
              Text(
                '内存监控',
                style: TextStyle(
                  color: foreground,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
