import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// The app's palette, fixed to the prototype.
///
/// There is no theme switcher any more, so nothing here is mutable: [DeckTokens]
/// holds the values and this class only adds the derived tones. Widgets keep
/// reading `AppColors` rather than `DeckTokens` so the "current colour" stays a
/// single indirection even though the values no longer move.
abstract final class AppColors {
  /// `null` means "the platform UI font" — the prototype's
  /// `-apple-system, BlinkMacSystemFont, Segoe UI, …` stack, which is what
  /// Flutter already resolves to per platform.
  static const String? fontFamily = null;
  static const int fontSize = 14;
  static const int normalFontWeight = 400;
  static const int boldFontWeight = 700;

  static const Color background = DeckTokens.bg;
  static const Color panel = DeckTokens.surface;
  static const Color sidebar = DeckTokens.bg;
  static const Color border = DeckTokens.border;
  static const Color textPrimary = DeckTokens.fg;
  static const Color textMuted = DeckTokens.muted;
  static const Color accent = DeckTokens.accent;
  static final Color selection = DeckTokens.accentSoft;
  static const Color tabActive = DeckTokens.bg;
  static const Color tabInactive = Colors.transparent;
  static final Color tabHover = DeckTokens.fgSoft;

  // Derived tones, mirroring the prototype's `color-mix(in oklch, …)` rules.
  static Color get accentInk => DeckTokens.mix(accent, textPrimary, 0.68);
  static Color get accentSoft => DeckTokens.wash(accent, 0.14);
  static Color get okSoft => DeckTokens.wash(DeckTokens.ok, 0.12);
  static Color get warnSoft => DeckTokens.wash(DeckTokens.warnBar, 0.20);
  static Color get dangerSoft => DeckTokens.wash(DeckTokens.danger, 0.12);
  static Color get fgSoft => DeckTokens.wash(textPrimary, 0.06);

  /// Hard shadows: a 2px offset edge, never blurred.
  static List<BoxShadow> get shadowHard => <BoxShadow>[
    BoxShadow(
      color: DeckTokens.wash(textPrimary, 0.20),
      offset: const Offset(2, 2),
    ),
  ];

  static List<BoxShadow> get shadowSolid => <BoxShadow>[
    BoxShadow(color: textPrimary, offset: const Offset(2, 2)),
  ];
}
