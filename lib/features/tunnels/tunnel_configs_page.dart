import 'package:flutter/material.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/models/tunnel_config_item.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/deck_page.dart';
import '../../core/widgets/deck_widgets.dart';

/// Tunnel list. Each row exposes the forward type as an inline segmented
/// control (switching it takes effect immediately) plus a start/stop toggle,
/// matching the prototype's row-level controls.
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
    required this.onTypeChanged,
  });

  final List<TunnelConfigItem> tunnels;
  final List<SshProfileItem> profiles;
  final String? errorMessage;
  final VoidCallback onAdd;
  final ValueChanged<TunnelConfigItem> onStart;
  final ValueChanged<TunnelConfigItem> onStop;
  final ValueChanged<TunnelConfigItem> onEdit;
  final ValueChanged<TunnelConfigItem> onDelete;
  final void Function(TunnelConfigItem tunnel, TunnelForwardType type)
  onTypeChanged;

  @override
  State<TunnelConfigsPage> createState() => _TunnelConfigsPageState();
}

class _TunnelConfigsPageState extends State<TunnelConfigsPage> {
  static const double _actionsWidth = 196;

  String profileName(String profileId) {
    for (final profile in widget.profiles) {
      if (profile.id == profileId) return profile.name;
    }
    return '未知 SSH 配置';
  }

  Future<void> _confirmDelete(TunnelConfigItem tunnel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除隧道'),
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

  Color _statusColor(TunnelConfigItem tunnel) => switch (tunnel.status) {
    TunnelRuntimeStatus.forwarding => DeckTokens.ok,
    TunnelRuntimeStatus.waiting => DeckTokens.warnBar,
    TunnelRuntimeStatus.stopped => DeckTokens.border,
  };

  @override
  Widget build(BuildContext context) {
    return DeckPageScaffold(
      eyebrow: 'Port Forwarding',
      title: '端口转发',
      subtitle: '把本地或远程端口经 SSH 隧道转给另一端的服务。',
      actions: [
        DeckButton(
          label: '新增隧道',
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
              title: '还没有隧道',
              hint: '点击右上角「新增隧道」，只需填写远程端口，本地端口可自动分配。',
              icon: Icons.swap_horiz,
            )
          else
            SingleChildScrollView(
              child: DeckTable(
                flexWeights: const [1],
                headerLabels: const ['隧道'],
                trailingWidth: _actionsWidth,
                children: [
                  for (final tunnel in widget.tunnels)
                    DeckTableRow(
                      flexWeights: const [1],
                      statusColor: _statusColor(tunnel),
                      cells: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: DeckStatusSquare(
                                _statusColor(tunnel),
                                size: 8,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tunnel.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: DeckTokens.fg,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${tunnel.listenHost}:${tunnel.listenPortLabel} → ${tunnel.targetHost}:${tunnel.targetPort}',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'JetBrains Mono',
                                            fontFamilyFallback: DeckTokens.fontMono,
                                            fontSize: 11,
                                            color: DeckTokens.muted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Which SSH config owns this tunnel —
                                      // not obvious from the addresses alone.
                                      Flexible(
                                        child: Text(
                                          profileName(tunnel.sshProfileId),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'JetBrains Mono',
                                            fontFamilyFallback: DeckTokens.fontMono,
                                            fontSize: 11,
                                            color: DeckTokens.accentInk,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _TypeSegment(
                              value: tunnel.type,
                              onChanged: (type) =>
                                  widget.onTypeChanged(tunnel, type),
                            ),
                          ],
                        ),
                      ],
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

/// Two-state segmented control used for the forward direction.
class _TypeSegment extends StatelessWidget {
  const _TypeSegment({required this.value, required this.onChanged});

  final TunnelForwardType value;
  final ValueChanged<TunnelForwardType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in TunnelForwardType.values) ...[
          DeckButton(
            label: option == TunnelForwardType.local ? '本地' : '远程',
            dense: true,
            style: option == value
                ? DeckButtonStyle.solid
                : DeckButtonStyle.ghost,
            onPressed: () => onChanged(option),
          ),
          const SizedBox(width: 3),
        ],
      ],
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
