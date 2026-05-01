import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.panel,
        primary: AppColors.accent,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: _applyUiFont(base.textTheme),
      dividerColor: AppColors.border,
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }

  static TextTheme _applyUiFont(TextTheme textTheme) {
    return textTheme.copyWith(
      displayLarge: _applyTextStyle(
        textTheme.displayLarge,
        useBoldWeight: true,
      ),
      displayMedium: _applyTextStyle(
        textTheme.displayMedium,
        useBoldWeight: true,
      ),
      displaySmall: _applyTextStyle(
        textTheme.displaySmall,
        useBoldWeight: true,
      ),
      headlineLarge: _applyTextStyle(
        textTheme.headlineLarge,
        useBoldWeight: true,
      ),
      headlineMedium: _applyTextStyle(
        textTheme.headlineMedium,
        useBoldWeight: true,
      ),
      headlineSmall: _applyTextStyle(
        textTheme.headlineSmall,
        useBoldWeight: true,
      ),
      titleLarge: _applyTextStyle(textTheme.titleLarge, useBoldWeight: true),
      titleMedium: _applyTextStyle(textTheme.titleMedium, useBoldWeight: true),
      titleSmall: _applyTextStyle(textTheme.titleSmall, useBoldWeight: true),
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
    bool useBoldWeight = false,
  }) {
    final value = style.fontWeight?.value ?? FontWeight.normal.value;
    final targetValue = useBoldWeight || value >= FontWeight.w600.value
        ? AppColors.boldFontWeight
        : AppColors.normalFontWeight;
    return FontWeight.values.firstWhere(
      (weight) => weight.value == targetValue,
      orElse: () => useBoldWeight || value >= FontWeight.w600.value
          ? FontWeight.bold
          : FontWeight.normal,
    );
  }

  static TextStyle? _applyTextStyle(
    TextStyle? style, {
    bool useBoldWeight = false,
  }) {
    if (style == null) return null;
    final baseFontSize = style.fontSize;
    return style.copyWith(
      fontFamily: AppColors.fontFamily,
      fontSize: baseFontSize == null
          ? AppColors.fontSize.toDouble()
          : baseFontSize * AppColors.fontSize / 14,
      fontWeight: _fontWeightFor(style, useBoldWeight: useBoldWeight),
      color: AppColors.textPrimary,
    );
  }
}
