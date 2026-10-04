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

  /// Dart's message for [pattern] when it is not a valid regular expression,
  /// or null when it is fine.
  ///
  /// An empty pattern means "no rule", not a broken one — the terminal skips
  /// those silently. Anything else that fails to compile is a real typo, and
  /// `TerminalView` used to drop it without a word, so the highlight simply
  /// stopped working and nobody knew why. Both the theme page and the terminal
  /// now surface this.
  static String? patternError(String pattern) {
    if (pattern.isEmpty) return null;
    try {
      RegExp(pattern);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }
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
    background: Color(0xFFFAF9F5),
    panel: Color(0xFFFFFFFF),
    sidebar: Color(0xFFFAF9F5),
    accent: Color(0xFFD97757),
    textPrimary: Color(0xFF1F1E1D),
    textMuted: Color(0xFF6B6862),
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
    foreground: Color(0xFFDEDCD6),
    terminalBackground: Color(0xFF17181A),
    selectionColor: Color(0xFF3A3F44),
    cursorColor: Color(0xFFD9A24B),
    scrollbackLines: 10000,
    regexHighlights: [
      RegexHighlight(
        pattern:
            r'[dlbcps-]([r-][w-][xs-]){3}|\broot\b|\bsudo\b|\bchmod\b|\bchown\b',
        color: Color(0xFFC1794F),
        note: 'Linux权限与用户',
      ),
      RegexHighlight(
        pattern: r'(?:^|\s)(?:/[^\s]*|\./[^\s]*|\.\./[^\s]*|~[^\s]*)',
        color: Color(0xFFE0C828),
        note: 'Linux文件路径',
      ),
      RegexHighlight(
        pattern:
            r'\b(if|then|else|elif|fi|case|esac|for|while|until|do|done|in|function|return|exit|break|continue)\b',
        color: Color(0xFFFF1495),
        note: 'Shell关键字与流程控制',
      ),
      RegexHighlight(
        pattern:
            r'\b(SUCCESS|PASS|OK|DONE|COMPLETE|ERROR|FAIL|FAILED|FATAL|CRITICAL)\b|✓|✗|❌|✅',
        color: Color(0xFF1EBF19),
        note: '成功/错误状态',
      ),
      RegexHighlight(
        pattern:
            r'https?://[^\s]+|ftp://[^\s]+|www\.[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?',
        color: Color(0xFF3F8EE8),
        note: '网址链接',
      ),
      RegexHighlight(
        pattern: r'''"[^"]*"|'[^']*'|`[^`]*`''',
        color: Color(0xFF5E923D),
        note: '字符串与引号',
      ),
      RegexHighlight(
        pattern: r'\$[A-Za-z_][A-Za-z0-9_]*|--?[A-Za-z][A-Za-z0-9-]*',
        color: Color(0xFFCC703A),
        note: '环境变量与参数',
      ),
      RegexHighlight(
        pattern:
            r'\b(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?\b|\b(?:localhost|127\.0\.0\.1)\b',
        color: Color(0xFF459BFF),
        note: '网络与IP地址',
      ),
      RegexHighlight(
        pattern:
            r'\b\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}(?::\d{2})?\b|\b\d{2}:\d{2}(?::\d{2})?\b',
        color: Color(0xFF7960FF),
        note: '时间与日期',
      ),
      RegexHighlight(
        pattern: r'\b\d+(?:\.\d+)?\s*(?:[KMGT]i?B|%|MB|GB|KB)?\b',
        color: Color(0xFF1AA416),
        note: '数字与计数',
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
