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
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      dividerColor: AppColors.border,
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}
