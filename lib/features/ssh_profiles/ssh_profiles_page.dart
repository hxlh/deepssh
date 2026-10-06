import 'package:flutter/material.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/deck_fields.dart';
import '../../core/widgets/deck_page.dart';
import '../../core/widgets/deck_widgets.dart';

/// SSH connection list. Layout follows the prototype: page head with a single
/// primary action, a search + auth filter toolbar, then a bordered table whose
/// left rule carries per-row status.
class SshProfilesPage extends StatefulWidget {
  const SshProfilesPage({
    super.key,
    required this.profiles,
    required this.errorMessage,
    required this.onAdd,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
    this.onlineProfileIds = const <String>{},
    this.lastConnectedAt = const <String, DateTime>{},
  });

  final List<SshProfileItem> profiles;
  final String? errorMessage;
  final VoidCallback onAdd;
  final ValueChanged<SshProfileItem> onConnect;
  final ValueChanged<SshProfileItem> onEdit;
  final ValueChanged<SshProfileItem> onDelete;

  /// Profiles with at least one open session. The prototype shows an
  /// 在线/已停止 badge; open sessions are the honest signal we have.
  final Set<String> onlineProfileIds;

  /// Last successful connect per profile, shown in the middle column.
  final Map<String, DateTime> lastConnectedAt;

  @override
  State<SshProfilesPage> createState() => _SshProfilesPageState();
}

class _SshProfilesPageState extends State<SshProfilesPage> {
  final _searchController = TextEditingController();
  String _query = '';
  SshAuthMode? _authFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SshProfileItem> get _visibleProfiles {
    final query = _query.trim().toLowerCase();
    return widget.profiles.where((profile) {
      if (_authFilter != null && profile.authMode != _authFilter) return false;
      if (query.isEmpty) return true;
      return profile.name.toLowerCase().contains(query) ||
          profile.host.toLowerCase().contains(query) ||
          profile.username.toLowerCase().contains(query);
    }).toList();
  }

  String _lastConnectedLabel(String profileId) {
    final at = widget.lastConnectedAt[profileId];
    if (at == null) return '—';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    final ss = at.second.toString().padLeft(2, '0');
    if (day == today) return '$hh:$mm:$ss';
    if (day == today.subtract(const Duration(days: 1))) return '昨天 $hh:$mm';
    return '${at.month}/${at.day} $hh:$mm';
  }

  Future<void> _confirmDelete(SshProfileItem profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: DeckTokens.wash(AppColors.textPrimary, 0.42),
      builder: (context) => DeckDialog(
        title: '删除 SSH 配置',
        message: '删除「${profile.name}」后不可恢复，确定继续？',
        actions: [
          DeckButton(
            label: '取消',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          DeckButton(
            label: '删除',
            style: DeckButtonStyle.danger,
            destructive: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete(profile);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleProfiles;
    const actionsWidth = 196.0;

    return DeckPageScaffold(
      eyebrow: 'SSH Profiles',
      title: '连接配置',
      subtitle:
          '管理远程主机凭据、认证方式与终端类型。共 ${widget.profiles.length} 个配置，'
          '其中 ${widget.onlineProfileIds.length} 个在线。',
      actions: [
        DeckButton(
          label: '新增 SSH 配置',
          style: DeckButtonStyle.accent,
          icon: Icons.add,
          onPressed: widget.onAdd,
        ),
      ],
      toolbar: Row(
        children: [
          SizedBox(
            width: 340,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: DeckTokens.fontMono,
                fontSize: 12,
              ),
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: '搜索名称、主机或用户名…',
                prefixIcon: Icon(Icons.search, size: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _AuthFilterSelect(
            selected: _authFilter,
            onChanged: (mode) => setState(() => _authFilter = mode),
          ),
          const Spacer(),
          DeckLabel('${visible.length} / ${widget.profiles.length}', size: 11),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.errorMessage != null) ...[
            _ErrorStrip(widget.errorMessage!),
            const SizedBox(height: 10),
          ],
          if (visible.isEmpty)
            DeckEmptyState(
              title: widget.profiles.isEmpty ? '还没有 SSH 配置' : '没有匹配的 SSH 配置',
              hint: widget.profiles.isEmpty
                  ? '点击右上角「新增 SSH 配置」保存第一台主机。'
                  : '换一个关键词，或清除认证方式筛选。',
              icon: Icons.dns_outlined,
            )
          else
            SingleChildScrollView(
              child: DeckTable(
                flexWeights: const [1],
                trailingWidth: actionsWidth,
                headerLabels: const [],
                showHeader: false,
                children: [
                  for (final profile in visible)
                    DeckTableRow(
                      flexWeights: const [1],
                      statusColor: widget.onlineProfileIds.contains(profile.id)
                          ? DeckTokens.ok
                          : AppColors.border,
                      cells: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    profile.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _OnlineBadge(
                                  online: widget.onlineProfileIds.contains(
                                    profile.id,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                DeckBadge(
                                  profile.authMode == SshAuthMode.password
                                      ? '密码'
                                      : '私钥',
                                ),
                                const SizedBox(width: 6),
                                DeckBadge(profile.termType),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${profile.username}@${profile.host}:${profile.port}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontFamilyFallback: DeckTokens.fontMono,
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                      meta: (
                        label: '最近使用',
                        value: _lastConnectedLabel(profile.id),
                      ),
                      trailingWidth: actionsWidth,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DeckButton(
                            label: '连接',
                            dense: true,
                            onPressed: () => widget.onConnect(profile),
                          ),
                          const SizedBox(width: 6),
                          DeckButton(
                            label: '编辑',
                            dense: true,
                            style: DeckButtonStyle.ghost,
                            onPressed: () => widget.onEdit(profile),
                          ),
                          const SizedBox(width: 6),
                          DeckButton(
                            label: '删除',
                            dense: true,
                            style: DeckButtonStyle.ghost,
                            destructive: true,
                            onPressed: () => _confirmDelete(profile),
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

class _AuthFilterSelect extends StatelessWidget {
  const _AuthFilterSelect({required this.selected, required this.onChanged});

  final SshAuthMode? selected;
  final ValueChanged<SshAuthMode?> onChanged;

  static const _options = <SshAuthMode?>[
    null,
    SshAuthMode.password,
    SshAuthMode.privateKey,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: DeckSelect<SshAuthMode?>(
        key: const ValueKey('auth-filter'),
        hint: '按认证方式筛选',
        value: selected,
        items: _options,
        itemBuilder: (context, mode) => Text(switch (mode) {
          null => '全部认证方式',
          SshAuthMode.password => '密码',
          SshAuthMode.privateKey => '私钥',
        }),
        onChanged: onChanged,
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    if (!online) return const DeckBadge('已停止');
    return DeckStatusBadge(
      label: '在线',
      color: DeckTokens.ok,
      background: AppColors.okSoft,
      borderColor: DeckTokens.mix(DeckTokens.ok, AppColors.border, 0.4),
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
        color: AppColors.dangerSoft,
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
