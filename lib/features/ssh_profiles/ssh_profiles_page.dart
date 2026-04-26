import 'package:flutter/material.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/theme/app_colors.dart';

class SshProfilesPage extends StatelessWidget {
  const SshProfilesPage({
    super.key,
    required this.profiles,
    required this.errorMessage,
    required this.onAdd,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
  });

  final List<SshProfileItem> profiles;
  final String? errorMessage;
  final VoidCallback onAdd;
  final ValueChanged<SshProfileItem> onConnect;
  final ValueChanged<SshProfileItem> onEdit;
  final ValueChanged<SshProfileItem> onDelete;

  Future<void> confirmDelete(
    BuildContext context,
    SshProfileItem profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete SSH Profile'),
        content: Text('Delete ${profile.name}?'),
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
      onDelete(profile);
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
                  'SSH Configurations',
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
              itemCount: profiles.length,
              separatorBuilder: (_, _) =>
                  Divider(color: AppColors.border),
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  tileColor: AppColors.tabInactive,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  title: Text(profile.name),
                  subtitle: Text(
                    '${profile.username}@${profile.host}:${profile.port}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => onConnect(profile),
                        child: const Text('连接'),
                      ),
                      TextButton(
                        onPressed: () => onEdit(profile),
                        child: const Text('编辑'),
                      ),
                      TextButton(
                        onPressed: () => confirmDelete(context, profile),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
