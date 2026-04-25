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
    required this.onCloseSshSession,
    required this.onCloseLocalTerminal,
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
  final Future<void> Function(SshSessionItem) onCloseSshSession;
  final Future<void> Function(LocalTerminalItem) onCloseLocalTerminal;

  Future<void> _showCloseMenu({
    required BuildContext context,
    required Offset position,
    required String label,
    required Future<void> Function() onClose,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [PopupMenuItem<String>(value: 'close', child: Text(label))],
    );
    if (selected == 'close') {
      await onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
          ...sshProfiles.expand((profile) {
            final sessions =
                sshSessionsByProfileId[profile.id] ?? const <SshSessionItem>[];
            return [
              InkWell(
                onTap: () => onSshProfileTap(profile),
                child: Container(
                  height: AppSpacing.itemHeight,
                  margin: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.computer,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          profile.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...sessions.map(
                (session) => InkWell(
                  onTap: () => onSshSessionTap(session),
                  onSecondaryTapDown: (details) {
                    _showCloseMenu(
                      context: context,
                      position: details.globalPosition,
                      label: '关闭 SSH 会话',
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
                        const Icon(
                          Icons.terminal,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          }),
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
                      localExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const Icon(
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
            ...localTerminals.map(
              (terminal) => InkWell(
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
                      const Icon(
                        Icons.terminal,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          terminal.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
