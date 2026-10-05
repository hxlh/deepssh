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

  /// The first family in the comma-separated [fontFamily] stack, or null when
  /// the stack is empty (platform default). Flutter's [TextStyle] takes one
  /// family plus a fallback list, so a CSS-style stack is split here.
  static String? get fontFamilyPrimary => DeckTokens.resolveFontStack(
    fontFamily,
    DeckTokens.fontBody,
    'sans-serif',
  ).$1;

  /// The rest of the [fontFamily] stack, then the built-in body fallbacks, so
  /// a partial stack still lands on a CJK-capable family.
  static List<String> get fontFamilyFallback => DeckTokens.resolveFontStack(
    fontFamily,
    DeckTokens.fontBody,
    'sans-serif',
  ).$2;

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

  // Derived tones, recomputed from the live settings so a non-default preset
  // stays coherent. Widgets must read these rather than [DeckTokens]: the
  // tokens are the palette definition, not the current theme.
  static Color get accentInk => DeckTokens.mix(accent, textPrimary, 0.68);
  static Color get accentSoft => DeckTokens.wash(accent, 0.14);
  static Color get okSoft => DeckTokens.wash(DeckTokens.ok, 0.12);
  static Color get warnSoft => DeckTokens.wash(DeckTokens.warnBar, 0.20);
  static Color get dangerSoft => DeckTokens.wash(DeckTokens.danger, 0.12);
  static Color get fgSoft => DeckTokens.wash(textPrimary, 0.06);

  /// Opaque hover wash for solid surfaces (buttons). [fgSoft] is a 6%-alpha
  /// overlay meant to tint *behind* text; on an opaque button it would let the
  /// row/selection background bleed through, so buttons mix toward the ink
  /// instead of going translucent.
  static Color get surfaceHover => DeckTokens.mix(panel, textPrimary, 0.06);

  /// The shadow ink: a hard offset edge in the current text colour, so it
  /// flips with a dark preset instead of staying grey-on-dark.
  static Color get shadowInk => DeckTokens.wash(textPrimary, 0.20);

  /// Fully opaque hard shadow (dialogs, drawers, floating layers).
  static Color get shadowSolidInk => textPrimary;

  static List<BoxShadow> get shadowHard => const <BoxShadow>[];

  static List<BoxShadow> get shadowSolid => const <BoxShadow>[];

  /// Chrome that stays put whatever the preset: status colours, the terminal
  /// stage and the font stacks all read [DeckTokens] directly.
}
