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
    // The set the app actually ships with, in this order: earlier rules win
    // when two patterns overlap, so the specific ones come first.
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
}
