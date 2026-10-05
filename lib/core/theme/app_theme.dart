import 'package:flutter/material.dart';

import '../widgets/deck_widgets.dart';
import 'app_colors.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static const BorderRadius _square = BorderRadius.zero;

  /// Built against the *live* [AppColors], not the palette constants, so a
  /// dark preset repaints menus, tooltips, scrollbars and Material buttons too.
  ///
  /// Callers must rebuild when the theme changes — `main.dart` does that via
  /// `onThemeChanged`.
  static ThemeData deck() {
    final dark = AppColors.background.computeLuminance() < 0.5;
    final base = dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    final scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: AppColors.accent,
      onPrimary: AppColors.panel,
      secondary: AppColors.accent,
      onSecondary: AppColors.panel,
      error: DeckTokens.danger,
      onError: AppColors.panel,
      surface: AppColors.panel,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.background,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      splashFactory: NoSplash.splashFactory,
      hoverColor: AppColors.fgSoft,
      highlightColor: AppColors.accentSoft,
      focusColor: AppColors.accentSoft,
      textTheme: _applyUiFont(base.textTheme),
      inputDecorationTheme: deckInputTheme(),

      // Zero radius is a global rule, not a per-widget decision.
      cardTheme: CardThemeData(
        color: AppColors.panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: _square,
          side: BorderSide(color: AppColors.textPrimary),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _square,
          side: BorderSide(color: AppColors.textPrimary),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _square,
          side: BorderSide(color: AppColors.textPrimary),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DeckTokens.border,
        space: 1,
        thickness: 1,
      ),
      iconTheme: IconThemeData(color: AppColors.textMuted, size: 16),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: _square,
        ),
        textStyle: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: DeckTokens.fontMono,
          fontSize: 11,
          color: AppColors.background,
        ),
      ),

      // Material's own buttons stay unrounded even though most call sites use
      // DeckButton directly.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.background,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: _square,
            side: BorderSide(color: AppColors.textPrimary),
          ),
          textStyle: _buttonTextStyle(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          shape: const RoundedRectangleBorder(borderRadius: _square),
          textStyle: _buttonTextStyle(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          shape: const RoundedRectangleBorder(borderRadius: _square),
          textStyle: _buttonTextStyle(),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(
          DeckTokens.mix(AppColors.textMuted, AppColors.background, 0.5),
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

  /// Label style for Material's own buttons.
  ///
  /// `ButtonStyleButton` hands this style to its `Material` as `textStyle`,
  /// which *replaces* the inherited default text style instead of merging with
  /// it. Naming the deck UI font here is what keeps `TextButton` labels (for
  /// example the theme page's "添加规则") on the same font stack as the rest of
  /// the UI; without it they fall back to the platform default.
  static TextStyle _buttonTextStyle() => TextStyle(
    fontFamily: AppColors.fontFamilyPrimary,
    fontFamilyFallback: AppColors.fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static FontWeight _fontWeightFor(TextStyle style, {bool bold = false}) {
    final value = style.fontWeight?.value ?? FontWeight.normal.value;
    final target = bold || value >= FontWeight.w600.value
        ? AppColors.boldFontWeight
        : AppColors.normalFontWeight;
    return FontWeight.values.firstWhere(
      (weight) => weight.value == target,
      orElse: () => bold || value >= FontWeight.w600.value
          ? FontWeight.bold
          : FontWeight.normal,
    );
  }

  static TextStyle? _applyTextStyle(TextStyle? style, {bool bold = false}) {
    if (style == null) return null;
    final baseFontSize = style.fontSize;
    return style.copyWith(
      fontFamily: AppColors.fontFamilyPrimary,
      fontFamilyFallback: AppColors.fontFamilyFallback,
      fontSize: baseFontSize == null
          ? AppColors.fontSize.toDouble()
          : baseFontSize * AppColors.fontSize / 14,
      fontWeight: _fontWeightFor(style, bold: bold),
      color: AppColors.textPrimary,
    );
  }
}
