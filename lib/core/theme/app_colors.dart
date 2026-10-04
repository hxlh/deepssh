import 'package:flutter/material.dart';

import '../models/theme_settings.dart';
import 'app_tokens.dart';

/// Runtime palette.
///
/// The base tokens live in [DeckTokens] and are locked; this class resolves
/// them against the user's `UiThemeSettings` so a saved theme still wins. The
/// field names are kept stable because a lot of widgets read them directly, but
/// everything that is *not* persisted (border, tab washes, selection) is derived
/// here rather than stored, so it can never drift from the base tokens.
abstract final class AppColors {
  static String fontFamily = 'Inter';
  static int fontSize = 14;
  static int normalFontWeight = 500;
  static int boldFontWeight = 700;

  static Color background = DeckTokens.bg;
  static Color panel = DeckTokens.surface;
  static Color sidebar = DeckTokens.bg;
  static Color border = DeckTokens.border;
  static Color textPrimary = DeckTokens.fg;
  static Color textMuted = DeckTokens.muted;
  static Color accent = DeckTokens.accent;
  static Color selection = DeckTokens.accentSoft;
  static Color tabActive = DeckTokens.bg;
  static Color tabInactive = Colors.transparent;
  static Color tabHover = DeckTokens.fgSoft;

  /// Applies a persisted UI theme, then re-derives everything that is not
  /// stored so the derived colours stay consistent with the chosen base.
  static void applyUi(UiThemeSettings settings) {
    fontFamily = settings.fontFamily;
    fontSize = settings.fontSize;
    normalFontWeight = settings.normalFontWeight;
    boldFontWeight = settings.boldFontWeight;
    background = settings.background;
    panel = settings.panel;
    sidebar = settings.sidebar;
    accent = settings.accent;
    textPrimary = settings.textPrimary;
    textMuted = settings.textMuted;

    border = DeckTokens.mix(DeckTokens.border, settings.textPrimary, 0.12);
    selection = DeckTokens.mix(settings.accent, settings.textPrimary, 0.14);
    tabActive = settings.background;
    tabInactive = Colors.transparent;
    tabHover = DeckTokens.wash(settings.textPrimary, 0.06);
  }

  static void applyTerminal(TerminalThemeSettings settings) {}
}
