import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../../core/theme/app_colors.dart';
import 'terminal_state.dart';

class TerminalView extends StatefulWidget {
  const TerminalView({super.key, required this.tab});

  final OpenTerminalTab tab;

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  late final xterm.Terminal terminal;

  @override
  void initState() {
    super.initState();
    terminal = xterm.Terminal(maxLines: 1000);
    terminal.write('Connected to ${widget.tab.welcomeTarget}\r\n');
    terminal.write('DeepSSH UI prototype terminal\r\n');
    terminal.write('\r\n');
    terminal.write(r'$ echo hello from xterm.dart\r\n');
    terminal.write('hello from xterm.dart\r\n');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.panel,
      padding: const EdgeInsets.all(12),
      child: xterm.TerminalView(
        terminal,
        autofocus: true,
        theme: const xterm.TerminalTheme(
          cursor: AppColors.accent,
          selection: AppColors.selection,
          foreground: AppColors.textPrimary,
          background: AppColors.panel,
          black: Color(0xFF000000),
          red: Color(0xFFCD3131),
          green: Color(0xFF0DBC79),
          yellow: Color(0xFFE5E510),
          blue: Color(0xFF2472C8),
          magenta: Color(0xFFBC3FBC),
          cyan: Color(0xFF11A8CD),
          white: Color(0xFFE5E5E5),
          brightBlack: Color(0xFF666666),
          brightRed: Color(0xFFF14C4C),
          brightGreen: Color(0xFF23D18B),
          brightYellow: Color(0xFFF5F543),
          brightBlue: Color(0xFF3B8EEA),
          brightMagenta: Color(0xFFD670D6),
          brightCyan: Color(0xFF29B8DB),
          brightWhite: Color(0xFFE5E5E5),
          searchHitBackground: Color(0xFF264F78),
          searchHitBackgroundCurrent: Color(0xFF515C6A),
          searchHitForeground: AppColors.textPrimary,
        ),
      ),
    );
  }
}
