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
    this.onReorderProfiles,
    this.onReorderSessions,
    this.onReorderLocalTerminals,
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
  final void Function(int oldIndex, int newIndex)? onReorderProfiles;
  final void Function(String profileId, int oldIndex, int newIndex)?
  onReorderSessions;
  final void Function(int oldIndex, int newIndex)? onReorderLocalTerminals;

  static const Color _menuAccent = Color(0xFFFFB280);
  static const double _menuItemHeight = 32;
  static const double _menuWidth = 150;

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
          color: selectedTerminalId == session.id
              ? AppColors.selection
              : Colors.transparent,
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

  @override
  Widget build(BuildContext context) {
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
                  })
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: sshProfiles.length,
                    onReorder: onReorderProfiles ?? (_, __) {},
                    itemBuilder: (context, profileIndex) {
                      final profile = sshProfiles[profileIndex];
                      final sessions =
                          sshSessionsByProfileId[profile.id] ??
                          const <SshSessionItem>[];
                      return Column(
                        key: ValueKey('profile-${profile.id}'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ReorderableDragStartListener(
                            index: profileIndex,
                            child: _profileHeader(profile),
                          ),
                          if (sessions.isNotEmpty)
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: sessions.length,
                              onReorder: (oldIndex, newIndex) {
                                onReorderSessions?.call(
                                  profile.id,
                                  oldIndex,
                                  newIndex,
                                );
                              },
                              itemBuilder: (context, sessionIndex) {
                                return ReorderableDragStartListener(
                                  index: sessionIndex,
                                  key: ValueKey(
                                    'session-${sessions[sessionIndex].id}',
                                  ),
                                  child: _sessionItem(
                                    context,
                                    sessions[sessionIndex],
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                if (localTerminals.isNotEmpty) ...[
                  InkWell(
                    onTap: onToggleLocal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        height: AppSpacing.itemHeight,
                        child: Row(
                          children: [
                            Icon(
                              localExpanded
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            Icon(
                              Icons.laptop,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            const Text('Local'),
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
                          child: _localTerminalItem(
                            context,
                            localTerminals[index],
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
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
