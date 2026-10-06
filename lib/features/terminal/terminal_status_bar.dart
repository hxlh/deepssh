import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_colors.dart';
import 'terminal_state.dart';

/// Terminal status strip.
///
/// The prototype inverts this bar — ink background with paper text — so it
/// reads as the bottom edge of the terminal stage rather than another chrome
/// surface.
class TerminalStatusBar extends StatelessWidget {
  const TerminalStatusBar({
    super.key,
    required this.tab,
    required this.connected,
  });

  final OpenTerminalTab? tab;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final xterm.Terminal? terminal = tab?.terminal;
    final columns = terminal?.viewWidth ?? 0;
    final rows = terminal?.viewHeight ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.textPrimary,
      child: Row(
        children: [
          _Item(
            leading: DeckStatusDot(
              connected ? DeckTokens.termGreen : DeckTokens.warnBar,
            ),
            text: _stateLabel,
          ),
          if (tab != null && tab!.hostName.isNotEmpty) ...[
            const SizedBox(width: 14),
            _Item(text: tab!.hostName),
          ],
          const Spacer(),
          const _Item(text: 'UTF-8', dim: true),
          if (tab?.termType != null) ...[
            const SizedBox(width: 14),
            _Item(text: tab!.termType!, dim: true),
          ],
          const SizedBox(width: 14),
          if (columns > 0 && rows > 0) _Item(text: '$columns×$rows', dim: true),
        ],
      ),
    );
  }

  String get _stateLabel {
    if (tab == null) return '未打开';
    if (!connected) return '连接中';
    return switch (tab!.sourceType) {
      TerminalSourceType.local => '本地终端',
      TerminalSourceType.ssh || TerminalSourceType.remote => '已连接',
    };
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.text, this.leading, this.dim = false});

  final String text;
  final Widget? leading;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        Text(
          text,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontFamilyFallback: DeckTokens.fontMono,
            fontSize: 10.5,
            color: dim
                ? DeckTokens.mix(
                    AppColors.background,
                    AppColors.textPrimary,
                    0.28,
                  )
                : AppColors.background,
          ),
        ),
      ],
    );
  }
}

/// Square status mark sized for the status bar.
class DeckStatusDot extends StatelessWidget {
  const DeckStatusDot(this.color, {super.key, this.size = 7});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, color: color);
  }
}
