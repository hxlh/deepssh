import 'package:flutter/material.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/models/tunnel_config_item.dart';
import '../../core/theme/app_colors.dart';

class TunnelConfigsPage extends StatelessWidget {
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

  String profileName(String profileId) {
    for (final profile in profiles) {
      if (profile.id == profileId) return profile.name;
    }
    return 'Missing SSH profile';
  }

  Future<void> confirmDelete(
    BuildContext context,
    TunnelConfigItem tunnel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tunnel Connection'),
        content: Text('Delete ${tunnel.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onDelete(tunnel);
    }
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
              const Expanded(
                child: Text(
                  'Tunnel Connections',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(onPressed: onAdd, child: const Text('新增')),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: tunnels.length,
              separatorBuilder: (_, _) => Divider(color: AppColors.border),
              itemBuilder: (context, index) {
                final tunnel = tunnels[index];
                return _TunnelRow(
                  tunnel: tunnel,
                  subtitle:
                      '${tunnel.forwardingSummary} via ${profileName(tunnel.sshProfileId)}',
                  onStart: () => onStart(tunnel),
                  onStop: () => onStop(tunnel),
                  onEdit: () => onEdit(tunnel),
                  onDelete: () => confirmDelete(context, tunnel),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TunnelRow extends StatelessWidget {
  const _TunnelRow({
    required this.tunnel,
    required this.subtitle,
    required this.onStart,
    required this.onStop,
    required this.onEdit,
    required this.onDelete,
  });

  final TunnelConfigItem tunnel;
  final String subtitle;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const Color _dotGreen = Color(0xFF3DDC84);
  static const Color _dotRed = Color(0xFFE05252);
  static const Color _buttonBg = Color(0xFF25282A);
  static const Color _buttonBorder = Color(0xFF3A3A3A);

  @override
  Widget build(BuildContext context) {
    final running = tunnel.isRunning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.tabInactive,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tunnel.name, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          _TunnelActionButton(
            key: Key(
              running
                  ? 'tunnel-stop-${tunnel.id}'
                  : 'tunnel-start-${tunnel.id}',
            ),
            label: running ? '停止' : '启动',
            onPressed: running ? onStop : onStart,
          ),
          const SizedBox(width: 8),
          TextButton(
            key: Key('tunnel-edit-${tunnel.id}'),
            onPressed: onEdit,
            child: const Text('编辑'),
          ),
          TextButton(
            key: Key('tunnel-delete-${tunnel.id}'),
            onPressed: onDelete,
            child: const Text('删除'),
          ),
          const SizedBox(width: 8),
          Container(
            key: Key('tunnel-status-dot-${tunnel.id}'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: tunnel.isForwarding ? _dotGreen : _dotRed,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _TunnelActionButton extends StatelessWidget {
  const _TunnelActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: _TunnelRow._buttonBg,
        side: const BorderSide(color: _TunnelRow._buttonBorder),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
