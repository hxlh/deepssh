import 'package:flutter/material.dart';

enum CursorStyle { block, underline, bar }

class RegexHighlight {
  const RegexHighlight({
    required this.pattern,
    required this.color,
    this.note = '',
  });

  final String pattern;
  final Color color;
  final String note;

  RegexHighlight copyWith({String? pattern, Color? color, String? note}) =>
      RegexHighlight(
        pattern: pattern ?? this.pattern,
        color: color ?? this.color,
        note: note ?? this.note,
      );
}

class UiThemeSettings {
  const UiThemeSettings({
    required this.presetName,
    required this.fontFamily,
    required this.fontSize,
    required this.normalFontWeight,
    required this.boldFontWeight,
    required this.background,
    required this.panel,
    required this.sidebar,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
  });

  final String presetName;
  final String fontFamily;
  final int fontSize;
  final int normalFontWeight;
  final int boldFontWeight;
  final Color background;
  final Color panel;
  final Color sidebar;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;

  UiThemeSettings copyWith({
    String? presetName,
    String? fontFamily,
    int? fontSize,
    int? normalFontWeight,
    int? boldFontWeight,
    Color? background,
    Color? panel,
    Color? sidebar,
    Color? accent,
    Color? textPrimary,
    Color? textMuted,
  }) => UiThemeSettings(
    presetName: presetName ?? this.presetName,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    normalFontWeight: normalFontWeight ?? this.normalFontWeight,
    boldFontWeight: boldFontWeight ?? this.boldFontWeight,
    background: background ?? this.background,
    panel: panel ?? this.panel,
    sidebar: sidebar ?? this.sidebar,
    accent: accent ?? this.accent,
    textPrimary: textPrimary ?? this.textPrimary,
    textMuted: textMuted ?? this.textMuted,
  );

  static UiThemeSettings commandDeck() => const UiThemeSettings(
    presetName: 'Command Deck',
    fontFamily: 'Inter',
    fontSize: 14,
    normalFontWeight: 500,
    boldFontWeight: 700,
    background: Color(0xFF1E1E1E),
    panel: Color(0xFF252526),
    sidebar: Color(0xFF181818),
    accent: Color(0xFF3794FF),
    textPrimary: Color(0xFFE6E6E6),
    textMuted: Color(0xFF9D9D9D),
  );

  static UiThemeSettings vsCodeDark() => const UiThemeSettings(
    presetName: 'VS Code Dark',
    fontFamily: 'Segoe UI',
    fontSize: 14,
    normalFontWeight: 500,
    boldFontWeight: 700,
    background: Color(0xFF1E1E1E),
    panel: Color(0xFF252526),
    sidebar: Color(0xFF181818),
    accent: Color(0xFF007ACC),
    textPrimary: Color(0xFFCCCCCC),
    textMuted: Color(0xFF858585),
  );
}

class TerminalThemeSettings {
  const TerminalThemeSettings({
    required this.presetName,
    required this.fontFamily,
    required this.fontSize,
    required this.normalFontWeight,
    required this.boldFontWeight,
    required this.cursorStyle,
    required this.cursorBlink,
    required this.foreground,
    required this.terminalBackground,
    required this.selectionColor,
    required this.cursorColor,
    required this.scrollbackLines,
    required this.regexHighlights,
  });

  final String presetName;
  final String fontFamily;
  final int fontSize;
  final int normalFontWeight;
  final int boldFontWeight;
  final CursorStyle cursorStyle;
  final bool cursorBlink;
  final Color foreground;
  final Color terminalBackground;
  final Color selectionColor;
  final Color cursorColor;
  final int scrollbackLines;
  final List<RegexHighlight> regexHighlights;

  TerminalThemeSettings copyWith({
    String? presetName,
    String? fontFamily,
    int? fontSize,
    int? normalFontWeight,
    int? boldFontWeight,
    CursorStyle? cursorStyle,
    bool? cursorBlink,
    Color? foreground,
    Color? terminalBackground,
    Color? selectionColor,
    Color? cursorColor,
    int? scrollbackLines,
    List<RegexHighlight>? regexHighlights,
  }) => TerminalThemeSettings(
    presetName: presetName ?? this.presetName,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    normalFontWeight: normalFontWeight ?? this.normalFontWeight,
    boldFontWeight: boldFontWeight ?? this.boldFontWeight,
    cursorStyle: cursorStyle ?? this.cursorStyle,
    cursorBlink: cursorBlink ?? this.cursorBlink,
    foreground: foreground ?? this.foreground,
    terminalBackground: terminalBackground ?? this.terminalBackground,
    selectionColor: selectionColor ?? this.selectionColor,
    cursorColor: cursorColor ?? this.cursorColor,
    scrollbackLines: scrollbackLines ?? this.scrollbackLines,
    regexHighlights: regexHighlights ?? this.regexHighlights,
  );

  static TerminalThemeSettings commandDeck() => const TerminalThemeSettings(
    presetName: 'Command Deck',
    fontFamily: 'JetBrains Mono',
    fontSize: 14,
    normalFontWeight: 400,
    boldFontWeight: 700,
    cursorStyle: CursorStyle.bar,
    cursorBlink: true,
    foreground: Color(0xFFE6E6E6),
    terminalBackground: Color(0xFF252526),
    selectionColor: Color(0xFF094771),
    cursorColor: Color(0xFF3794FF),
    scrollbackLines: 10000,
    regexHighlights: [
      RegexHighlight(
        pattern: 'ERROR|FATAL|Exception|Traceback',
        color: Color(0xFFF14C4C),
        note: '错误日志',
      ),
      RegexHighlight(
        pattern: 'WARN|WARNING',
        color: Color(0xFFF5F543),
        note: '警告日志',
      ),
      RegexHighlight(
        pattern: 'SUCCESS|OK|DONE',
        color: Color(0xFF23D18B),
        note: '成功状态',
      ),
      RegexHighlight(
        pattern: r'\b[45]\d\d\b',
        color: Color(0xFFF14C4C),
        note: 'HTTP 错误',
      ),
      RegexHighlight(
        pattern: r'\b\d+ms\b|\b\d+\.\d+s\b',
        color: Color(0xFF29B8DB),
        note: '耗时',
      ),
      RegexHighlight(
        pattern: r'\b(?:\d{1,3}\.){3}\d{1,3}\b',
        color: Color(0xFFD670D6),
        note: 'IP 地址',
      ),
      RegexHighlight(
        pattern: r'\b[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\b',
        color: Color(0xFF3B8EEA),
        note: 'UUID',
      ),
    ],
  );

  static TerminalThemeSettings oneDark() => const TerminalThemeSettings(
    presetName: 'One Dark',
    fontFamily: 'JetBrains Mono',
    fontSize: 14,
    normalFontWeight: 400,
    boldFontWeight: 700,
    cursorStyle: CursorStyle.block,
    cursorBlink: true,
    foreground: Color(0xFFABB2BF),
    terminalBackground: Color(0xFF282C34),
    selectionColor: Color(0xFF3E4451),
    cursorColor: Color(0xFF528BFF),
    scrollbackLines: 10000,
    regexHighlights: [],
  );

  static TerminalThemeSettings solarized() => const TerminalThemeSettings(
    presetName: 'Solarized',
    fontFamily: 'JetBrains Mono',
    fontSize: 14,
    normalFontWeight: 400,
    boldFontWeight: 700,
    cursorStyle: CursorStyle.block,
    cursorBlink: false,
    foreground: Color(0xFF839496),
    terminalBackground: Color(0xFF002B36),
    selectionColor: Color(0xFF073642),
    cursorColor: Color(0xFF93A1A1),
    scrollbackLines: 10000,
    regexHighlights: [],
  );
}
