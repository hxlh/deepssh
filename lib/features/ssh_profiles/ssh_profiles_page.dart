import 'package:flutter/material.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/theme/app_tokens.dart';
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
  });

  final List<SshProfileItem> profiles;
  final String? errorMessage;
  final VoidCallback onAdd;
  final ValueChanged<SshProfileItem> onConnect;
  final ValueChanged<SshProfileItem> onEdit;
  final ValueChanged<SshProfileItem> onDelete;

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

  Future<void> _confirmDelete(SshProfileItem profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 SSH 配置'),
        content: Text('删除「${profile.name}」后不可恢复，确定继续？'),
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
    if (confirmed == true) widget.onDelete(profile);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleProfiles;
    const actionsWidth = 196.0;

    return DeckPageScaffold(
      eyebrow: 'SSH',
      title: '连接配置',
      subtitle: '保存常用的 SSH 主机，选择一条即可直接连接。',
      actions: [
        DeckButton(
          label: '新增 SSH 配置',
          style: DeckButtonStyle.solid,
          icon: Icons.add,
          onPressed: widget.onAdd,
        ),
      ],
      toolbar: Row(
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: DeckTokens.fontMono,
                fontSize: 12,
              ),
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: '搜索名称 / 主机 / 用户名',
                prefixIcon: Icon(Icons.search, size: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _AuthFilter(
            selected: _authFilter,
            onChanged: (mode) => setState(() => _authFilter = mode),
          ),
          const Spacer(),
          DeckLabel('${visible.length} / ${widget.profiles.length}', size: 10),
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
            Expanded(
              child: DeckTable(
                flexWeights: const [1],
                trailingWidth: actionsWidth,
                headerLabels: const ['SSH 配置'],
                children: [
                  for (final profile in visible)
                    DeckTableRow(
                      flexWeights: const [1],
                      statusColor: DeckTokens.ok,
                      cells: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: DeckStatusSquare(
                                DeckTokens.ok,
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
                                    profile.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: DeckTokens.fg,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${profile.username}@${profile.host}:${profile.port}',
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
                            ),
                            const SizedBox(width: 12),
                            DeckBadge(
                              profile.authMode == SshAuthMode.password
                                  ? '密码'
                                  : '私钥',
                              foreground: DeckTokens.accentInk,
                              background: DeckTokens.accentSoft,
                              borderColor: DeckTokens.mix(
                                DeckTokens.accent,
                                DeckTokens.border,
                                0.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                      trailingWidth: actionsWidth,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DeckButton(
                            label: '连接',
                            dense: true,
                            onPressed: () => widget.onConnect(profile),
                          ),
                          const SizedBox(width: 5),
                          DeckButton(
                            label: '编辑',
                            dense: true,
                            style: DeckButtonStyle.ghost,
                            onPressed: () => widget.onEdit(profile),
                          ),
                          const SizedBox(width: 5),
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

class _AuthFilter extends StatelessWidget {
  const _AuthFilter({required this.selected, required this.onChanged});

  final SshAuthMode? selected;
  final ValueChanged<SshAuthMode?> onChanged;

  static const _options = <(String, SshAuthMode?)>[
    ('全部', null),
    ('密码', SshAuthMode.password),
    ('私钥', SshAuthMode.privateKey),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in _options) ...[
          DeckButton(
            key: ValueKey('auth-filter-${option.$1}'),
            label: option.$1,
            dense: true,
            style: selected == option.$2
                ? DeckButtonStyle.solid
                : DeckButtonStyle.ghost,
            onPressed: () => onChanged(option.$2),
          ),
          const SizedBox(width: 4),
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
