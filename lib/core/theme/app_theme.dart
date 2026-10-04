import 'package:flutter/material.dart';

import '../widgets/deck_widgets.dart';
import 'app_colors.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static const BorderRadius _square = BorderRadius.zero;

  static ThemeData deck() {
    final base = ThemeData.light(useMaterial3: true);

    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: DeckTokens.accent,
      onPrimary: DeckTokens.surface,
      secondary: DeckTokens.accent,
      onSecondary: DeckTokens.surface,
      error: DeckTokens.danger,
      onError: DeckTokens.surface,
      surface: DeckTokens.surface,
      onSurface: DeckTokens.fg,
      surfaceContainerHighest: DeckTokens.bg,
      onSurfaceVariant: DeckTokens.muted,
      outline: DeckTokens.border,
      outlineVariant: DeckTokens.border,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: DeckTokens.bg,
      canvasColor: DeckTokens.bg,
      dividerColor: DeckTokens.border,
      splashFactory: NoSplash.splashFactory,
      hoverColor: DeckTokens.fgSoft,
      highlightColor: DeckTokens.accentSoft,
      focusColor: DeckTokens.accentSoft,
      textTheme: _applyUiFont(base.textTheme),
      inputDecorationTheme: deckInputTheme(),

      // Zero radius is a global rule, not a per-widget decision.
      cardTheme: CardThemeData(
        color: DeckTokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: _square,
          side: BorderSide(color: DeckTokens.fg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: DeckTokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: _square,
          side: BorderSide(color: DeckTokens.fg),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: DeckTokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: _square,
          side: BorderSide(color: DeckTokens.fg),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DeckTokens.border,
        space: 1,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: DeckTokens.muted, size: 16),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: DeckTokens.fg,
          borderRadius: _square,
        ),
        textStyle: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: DeckTokens.fontMono,
          fontSize: 11,
          color: DeckTokens.bg,
        ),
      ),

      // Material's own buttons stay unrounded even though most call sites use
      // DeckButton directly.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DeckTokens.fg,
          foregroundColor: DeckTokens.bg,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: _square,
            side: BorderSide(color: DeckTokens.fg),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DeckTokens.fg,
          side: const BorderSide(color: DeckTokens.border),
          shape: const RoundedRectangleBorder(borderRadius: _square),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DeckTokens.fg,
          shape: const RoundedRectangleBorder(borderRadius: _square),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(
          DeckTokens.mix(DeckTokens.muted, DeckTokens.bg, 0.5),
        ),
        trackVisibility: const WidgetStatePropertyAll<bool>(false),
        thickness: const WidgetStatePropertyAll<double>(8),
        radius: Radius.zero,
      ),
    );
  }

  static TextTheme _applyUiFont(TextTheme textTheme) {
    return textTheme.copyWith(
      displayLarge: _applyTextStyle(textTheme.displayLarge, bold: true),
      displayMedium: _applyTextStyle(textTheme.displayMedium, bold: true),
      displaySmall: _applyTextStyle(textTheme.displaySmall, bold: true),
      headlineLarge: _applyTextStyle(textTheme.headlineLarge, bold: true),
      headlineMedium: _applyTextStyle(textTheme.headlineMedium, bold: true),
      headlineSmall: _applyTextStyle(textTheme.headlineSmall, bold: true),
      titleLarge: _applyTextStyle(textTheme.titleLarge, bold: true),
      titleMedium: _applyTextStyle(textTheme.titleMedium, bold: true),
      titleSmall: _applyTextStyle(textTheme.titleSmall, bold: true),
      bodyLarge: _applyTextStyle(textTheme.bodyLarge),
      bodyMedium: _applyTextStyle(textTheme.bodyMedium),
      bodySmall: _applyTextStyle(textTheme.bodySmall),
      labelLarge: _applyTextStyle(textTheme.labelLarge),
      labelMedium: _applyTextStyle(textTheme.labelMedium),
      labelSmall: _applyTextStyle(textTheme.labelSmall),
    );
  }

  static FontWeight _fontWeightFor(
    TextStyle style, {
    bool bold = false,
  }) {
    final value = style.fontWeight?.value ?? FontWeight.normal.value;
    final target = bold || value >= FontWeight.w600.value
        ? AppColors.boldFontWeight
        : AppColors.normalFontWeight;
    return FontWeight.values.firstWhere(
      (weight) => weight.value == target,
      orElse: () =>
          bold || value >= FontWeight.w600.value ? FontWeight.bold : FontWeight.normal,
    );
  }

  static TextStyle? _applyTextStyle(
    TextStyle? style, {
    bool bold = false,
  }) {
    if (style == null) return null;
    final baseFontSize = style.fontSize;
    return style.copyWith(
      fontFamily: AppColors.fontFamily,
      fontFamilyFallback: const <String>[
        '-apple-system',
        'Segoe UI',
        'PingFang SC',
        'Microsoft YaHei',
        'Noto Sans CJK SC',
      ],
      fontSize: baseFontSize == null
          ? AppColors.fontSize.toDouble()
          : baseFontSize * AppColors.fontSize / 14,
      fontWeight: _fontWeightFor(style, bold: bold),
      color: AppColors.textPrimary,
    );
  }
}
