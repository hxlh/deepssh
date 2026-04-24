import 'package:flutter/material.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/theme/app_colors.dart';

class SshProfilesPage extends StatelessWidget {
  const SshProfilesPage({super.key, required this.profiles});

  final List<SshProfileItem> profiles;

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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('新增'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: profiles.length,
              separatorBuilder: (_, _) => const Divider(color: AppColors.border),
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tileColor: AppColors.tabInactive,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  title: Text(profile.name),
                  subtitle: Text('${profile.username}@${profile.host}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
