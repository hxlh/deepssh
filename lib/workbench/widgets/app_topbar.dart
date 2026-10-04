import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/deck_widgets.dart';
import 'add_connection_button.dart';

/// The four user-visible pages. The shell maps [AppSection] onto the content
/// mode the workbench already uses, so navigation stays a pure view concern.
enum AppSection { workbench, connections, tunnels, theme }

/// Stable test/semantics handle for a nav entry.
Key appNavKey(AppSection section) => ValueKey('app-nav-${section.name}');

extension AppSectionMeta on AppSection {
  String get label => switch (this) {
    AppSection.workbench => '工作台',
    AppSection.connections => '连接配置',
    AppSection.tunnels => '端口转发',
    AppSection.theme => '主题配置',
  };

  IconData get icon => switch (this) {
    AppSection.workbench => Icons.terminal,
    AppSection.connections => Icons.dns_outlined,
    AppSection.tunnels => Icons.swap_horiz,
    AppSection.theme => Icons.palette_outlined,
  };
}

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.current,
    required this.onNavigate,
    required this.onAddConnection,
    this.sessionCount = 0,
    this.tunnelCount = 0,
  });

  final AppSection current;
  final ValueChanged<AppSection> onNavigate;
  final ValueChanged<AddConnectionAction> onAddConnection;
  final int sessionCount;
  final int tunnelCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: DeckTokens.surface,
        border: Border(bottom: BorderSide(color: DeckTokens.fg)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const _Brand(),
          const SizedBox(width: 18),
          for (final section in AppSection.values) ...[
            _NavButton(
              key: appNavKey(section),
              section: section,
              selected: section == current,
              badge: switch (section) {
                AppSection.workbench => sessionCount,
                AppSection.tunnels => tunnelCount,
                _ => 0,
              },
              onTap: () => onNavigate(section),
            ),
            const SizedBox(width: 2),
          ],
          const Spacer(),
          AddConnectionButton(onSelected: onAddConnection),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DeckTokens.accent,
            border: Border.all(color: DeckTokens.fg),
            boxShadow: DeckTokens.shadowSolid,
          ),
          child: const Text(
            'DS',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DeckTokens.surface,
            ),
          ),
        ),
        const SizedBox(width: 9),
        const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DeepSSH',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontFamilyFallback: DeckTokens.fontDisplay,
                fontSize: 15,
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: DeckTokens.fg,
              ),
            ),
            DeckLabel('SSH Workbench', size: 9.5, spacing: 0.14),
          ],
        ),
      ],
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    super.key,
    required this.section,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final AppSection section;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final foreground = widget.selected ? DeckTokens.fg : DeckTokens.muted;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.section.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: widget.selected
                  ? DeckTokens.bg
                  : (_hovered ? DeckTokens.fgSoft : Colors.transparent),
              border: Border.all(
                color: widget.selected ? DeckTokens.border : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.section.icon, size: 14, color: foreground),
                const SizedBox(width: 7),
                Text(
                  widget.section.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
                if (widget.badge > 0) ...[
                  const SizedBox(width: 5),
                  _Count(badge: widget.badge),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small inverted count chip used for open sessions and configured tunnels.
class _Count extends StatelessWidget {
  const _Count({required this.badge});

  final int badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      color: DeckTokens.fg,
      child: Text(
        '$badge',
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: DeckTokens.bg,
        ),
      ),
    );
  }
}
