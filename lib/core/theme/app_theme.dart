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
      displayLarge: _applyTextStyle(textTheme.displayLarge),
      displayMedium: _applyTextStyle(textTheme.displayMedium),
      displaySmall: _applyTextStyle(textTheme.displaySmall),
      headlineLarge: _applyTextStyle(textTheme.headlineLarge),
      headlineMedium: _applyTextStyle(textTheme.headlineMedium),
      headlineSmall: _applyTextStyle(textTheme.headlineSmall),
      titleLarge: _applyTextStyle(textTheme.titleLarge),
      titleMedium: _applyTextStyle(textTheme.titleMedium),
      titleSmall: _applyTextStyle(textTheme.titleSmall),
      bodyLarge: _applyTextStyle(textTheme.bodyLarge),
      bodyMedium: _applyTextStyle(textTheme.bodyMedium),
      bodySmall: _applyTextStyle(textTheme.bodySmall),
      labelLarge: _applyTextStyle(textTheme.labelLarge),
      labelMedium: _applyTextStyle(textTheme.labelMedium),
      labelSmall: _applyTextStyle(textTheme.labelSmall),
    );
  }

  static TextStyle? _applyTextStyle(TextStyle? style) {
    if (style == null) return null;
    final baseFontSize = style.fontSize;
    return style.copyWith(
      fontFamily: AppColors.fontFamily,
      fontSize: baseFontSize == null
          ? AppColors.fontSize.toDouble()
          : baseFontSize * AppColors.fontSize / 14,
      color: AppColors.textPrimary,
    );
  }
}
