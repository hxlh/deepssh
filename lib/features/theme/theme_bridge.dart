import 'package:flutter/material.dart';

import '../../core/models/theme_settings.dart';
import '../../core/widgets/css_colors.dart' as css;
import '../../src/rust/rust_init.dart';
import '../../src/rust/theme.dart' as rust_theme;

abstract class ThemeBridgeClient {
  Future<({UiThemeSettings ui, TerminalThemeSettings terminal})> loadTheme();

  Future<void> saveTheme({
    required UiThemeSettings ui,
    required TerminalThemeSettings terminal,
  });
}

class RustThemeBridgeClient implements ThemeBridgeClient {
  RustThemeBridgeClient();

  Future<void> _ensureInitialized() {
    return ensureRustInitialized();
  }

  @override
  Future<({UiThemeSettings ui, TerminalThemeSettings terminal})>
  loadTheme() async {
    await _ensureInitialized();
    final settings = await rust_theme.loadTheme();
    return (
      ui: _uiFromRust(settings.ui),
      terminal: _terminalFromRust(settings.terminal),
    );
  }

  @override
  Future<void> saveTheme({
    required UiThemeSettings ui,
    required TerminalThemeSettings terminal,
  }) async {
    await _ensureInitialized();
    await rust_theme.saveTheme(
      settings: rust_theme.ThemeSettings(
        ui: _uiToRust(ui),
        terminal: _terminalToRust(terminal),
      ),
    );
  }
}

class InMemoryThemeBridgeClient implements ThemeBridgeClient {
  UiThemeSettings _ui = UiThemeSettings.commandDeck();
  TerminalThemeSettings _terminal = TerminalThemeSettings.commandDeck();

  @override
  Future<({UiThemeSettings ui, TerminalThemeSettings terminal})>
  loadTheme() async {
    return (ui: _ui, terminal: _terminal);
  }

  @override
  Future<void> saveTheme({
    required UiThemeSettings ui,
    required TerminalThemeSettings terminal,
  }) async {
    _ui = ui;
    _terminal = terminal;
  }
}

UiThemeSettings _uiFromRust(rust_theme.UiTheme value) {
  return UiThemeSettings(
    presetName: value.presetName,
    fontFamily: value.fontFamily,
    fontSize: value.fontSize,
    background: css.hexToColor(value.background) ?? const Color(0xFF1E1E1E),
    panel: css.hexToColor(value.panel) ?? const Color(0xFF252526),
    sidebar: css.hexToColor(value.sidebar) ?? const Color(0xFF181818),
    accent: css.hexToColor(value.accent) ?? const Color(0xFF3794FF),
    textPrimary: css.hexToColor(value.textPrimary) ?? const Color(0xFFE6E6E6),
    textMuted: css.hexToColor(value.textMuted) ?? const Color(0xFF9D9D9D),
  );
}

rust_theme.UiTheme _uiToRust(UiThemeSettings value) {
  return rust_theme.UiTheme(
    presetName: value.presetName,
    fontFamily: value.fontFamily,
    fontSize: value.fontSize,
    background: css.colorToHex(value.background),
    panel: css.colorToHex(value.panel),
    sidebar: css.colorToHex(value.sidebar),
    accent: css.colorToHex(value.accent),
    textPrimary: css.colorToHex(value.textPrimary),
    textMuted: css.colorToHex(value.textMuted),
  );
}

TerminalThemeSettings _terminalFromRust(rust_theme.TerminalTheme value) {
  return TerminalThemeSettings(
    presetName: value.presetName,
    fontFamily: value.fontFamily,
    fontSize: value.fontSize,
    cursorStyle: cursorStyleFromString(value.cursorStyle),
    cursorBlink: value.cursorBlink,
    foreground: css.hexToColor(value.foreground) ?? const Color(0xFFE6E6E6),
    terminalBackground:
        css.hexToColor(value.terminalBackground) ?? const Color(0xFF252526),
    selectionColor:
        css.hexToColor(value.selectionColor) ?? const Color(0xFF094771),
    cursorColor: css.hexToColor(value.cursorColor) ?? const Color(0xFF3794FF),
    scrollbackLines: value.scrollbackLines,
    regexHighlights: value.regexHighlights
        .map(
          (highlight) => RegexHighlight(
            pattern: highlight.pattern,
            color: css.hexToColor(highlight.color) ?? const Color(0xFFE6E6E6),
            note: highlight.note,
          ),
        )
        .toList(growable: false),
  );
}

rust_theme.TerminalTheme _terminalToRust(TerminalThemeSettings value) {
  return rust_theme.TerminalTheme(
    presetName: value.presetName,
    fontFamily: value.fontFamily,
    fontSize: value.fontSize,
    cursorStyle: cursorStyleToString(value.cursorStyle),
    cursorBlink: value.cursorBlink,
    foreground: css.colorToHex(value.foreground),
    terminalBackground: css.colorToHex(value.terminalBackground),
    selectionColor: css.colorToHex(value.selectionColor),
    cursorColor: css.colorToHex(value.cursorColor),
    scrollbackLines: value.scrollbackLines,
    regexHighlights: value.regexHighlights
        .map(
          (highlight) => rust_theme.RegexHighlight(
            pattern: highlight.pattern,
            color: css.colorToHex(highlight.color),
            note: highlight.note,
          ),
        )
        .toList(growable: false),
  );
}

String cursorStyleToString(CursorStyle style) {
  switch (style) {
    case CursorStyle.block:
      return 'block';
    case CursorStyle.underline:
      return 'underline';
    case CursorStyle.bar:
      return 'bar';
  }
}

CursorStyle cursorStyleFromString(String value) {
  switch (value.toLowerCase()) {
    case 'block':
      return CursorStyle.block;
    case 'underline':
      return CursorStyle.underline;
    case 'bar':
      return CursorStyle.bar;
    default:
      return CursorStyle.bar;
  }
}
