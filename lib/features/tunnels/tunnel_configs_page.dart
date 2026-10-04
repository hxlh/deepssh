import 'package:flutter/material.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/models/tunnel_config_item.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/deck_page.dart';
import '../../core/widgets/deck_widgets.dart';

/// Tunnel list. Row layout follows the prototype: name + status + direction
/// badges over a `listen → target 经 profile` sub-line, then the listen port
/// as the middle column, then the actions.
class TunnelConfigsPage extends StatefulWidget {
  const TunnelConfigsPage({
    super.key,
    required this.tunnels,
    required this.profiles,
    required this.errorMessage,
    required this.onAdd,
    required this.onStart,
    required this.onStop,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TunnelConfigItem> tunnels;
  final List<SshProfileItem> profiles;
  final String? errorMessage;
  final VoidCallback onAdd;
  final ValueChanged<TunnelConfigItem> onStart;
  final ValueChanged<TunnelConfigItem> onStop;
  final ValueChanged<TunnelConfigItem> onEdit;
  final ValueChanged<TunnelConfigItem> onDelete;

  @override
  State<TunnelConfigsPage> createState() => _TunnelConfigsPageState();
}

class _TunnelConfigsPageState extends State<TunnelConfigsPage> {
  static const double _actionsWidth = 196;

  String profileName(String profileId) {
    for (final profile in widget.profiles) {
      if (profile.id == profileId) return profile.name;
    }
    return '未知配置';
  }

  Future<void> _confirmDelete(TunnelConfigItem tunnel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除转发'),
        content: Text('删除「${tunnel.name}」后不可恢复，确定继续？'),
        actions: [
          DeckButton(
            label: '取消',
            style: DeckButtonStyle.ghost,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          DeckButton(
            label: '删除',
            style: DeckButtonStyle.solid,
            destructive: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete(tunnel);
  }

  ({Color color, String label, Color background, Color border}) _status(
    TunnelConfigItem tunnel,
  ) => switch (tunnel.status) {
    TunnelRuntimeStatus.forwarding => (
      color: DeckTokens.ok,
      label: '运行中',
      background: DeckTokens.okSoft,
      border: DeckTokens.mix(DeckTokens.ok, DeckTokens.border, 0.4),
    ),
    TunnelRuntimeStatus.waiting => (
      color: DeckTokens.warn,
      label: '等待中',
      background: DeckTokens.warnSoft,
      border: DeckTokens.mix(DeckTokens.warnBar, DeckTokens.border, 0.45),
    ),
    TunnelRuntimeStatus.stopped => (
      color: DeckTokens.muted,
      label: '已停止',
      background: DeckTokens.bg,
      border: DeckTokens.border,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final running = widget.tunnels
        .where((t) => t.status == TunnelRuntimeStatus.forwarding)
        .length;

    return DeckPageScaffold(
      eyebrow: 'Port Forwarding',
      title: '端口转发',
      subtitle:
          '基于 SSH 配置的本地与远程隧道。共 ${widget.tunnels.length} 条，'
          '其中 $running 条运行中。',
      actions: [
        DeckButton(
          label: '新增转发',
          style: DeckButtonStyle.solid,
          icon: Icons.add,
          onPressed: widget.onAdd,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.errorMessage != null) ...[
            _ErrorStrip(widget.errorMessage!),
            const SizedBox(height: 10),
          ],
          if (widget.tunnels.isEmpty)
            DeckEmptyState(
              title: '还没有转发',
              hint: '点击右上角「新增转发」，只需填写远程端口，本地端口可自动分配。',
              icon: Icons.swap_horiz,
            )
          else
            SingleChildScrollView(
              child: DeckTable(
                flexWeights: const [1],
                headerLabels: const ['转发'],
                trailingWidth: _actionsWidth,
                children: [
                  for (final tunnel in widget.tunnels)
                    DeckTableRow(
                      flexWeights: const [1],
                      statusColor: switch (tunnel.status) {
                        TunnelRuntimeStatus.forwarding => DeckTokens.accent,
                        TunnelRuntimeStatus.waiting => DeckTokens.warnBar,
                        TunnelRuntimeStatus.stopped => DeckTokens.border,
                      },
                      cells: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    tunnel.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: DeckTokens.fg,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // The prototype's stopped badge carries no
                                // status dot — only 在线 / 运行中 / 等待中 do.
                                if (tunnel.status ==
                                    TunnelRuntimeStatus.stopped)
                                  const DeckBadge('已停止')
                                else
                                  DeckStatusBadge(
                                    label: _status(tunnel).label,
                                    color: _status(tunnel).color,
                                    background: _status(tunnel).background,
                                    borderColor: _status(tunnel).border,
                                  ),
                                const SizedBox(width: 6),
                                DeckBadge(
                                  tunnel.type == TunnelForwardType.local
                                      ? '本地转发'
                                      : '远程转发',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        '${tunnel.listenHost}:${tunnel.listenPortLabel}',
                                  ),
                                  TextSpan(
                                    text: '  →  ',
                                    style: const TextStyle(
                                      color: DeckTokens.muted,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        '${tunnel.targetHost}:${tunnel.targetPort}',
                                  ),
                                  const TextSpan(
                                    text: '  经  ',
                                    style: TextStyle(color: DeckTokens.muted),
                                  ),
                                  TextSpan(
                                    text: profileName(tunnel.sshProfileId),
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontFamilyFallback: DeckTokens.fontMono,
                                fontSize: 11,
                                color: DeckTokens.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                      meta: (
                        label: '监听端口',
                        value: tunnel.listenPort == 0
                            ? '自动分配'
                            : '${tunnel.listenPort}',
                      ),
                      trailingWidth: _actionsWidth,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DeckButton(
                            key: ValueKey(
                              tunnel.isRunning
                                  ? 'tunnel-stop-${tunnel.id}'
                                  : 'tunnel-start-${tunnel.id}',
                            ),
                            label: tunnel.isRunning ? '停止' : '启动',
                            dense: true,
                            onPressed: () => tunnel.isRunning
                                ? widget.onStop(tunnel)
                                : widget.onStart(tunnel),
                          ),
                          const SizedBox(width: 5),
                          DeckButton(
                            label: '编辑',
                            dense: true,
                            style: DeckButtonStyle.ghost,
                            onPressed: () => widget.onEdit(tunnel),
                          ),
                          const SizedBox(width: 5),
                          DeckButton(
                            label: '删除',
                            dense: true,
                            style: DeckButtonStyle.ghost,
                            destructive: true,
                            onPressed: () => _confirmDelete(tunnel),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: DeckTokens.dangerSoft,
        border: Border.all(color: DeckTokens.danger),
      ),
      child: Row(
        children: [
          const DeckStatusSquare(DeckTokens.danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: DeckTokens.danger),
            ),
          ),
        ],
      ),
    );
  }
}
