import 'package:flutter/material.dart';

import '../models/theme_settings.dart';

abstract final class AppColors {
  static String fontFamily = 'Inter';
  static int fontSize = 14;
  static int normalFontWeight = 500;
  static int boldFontWeight = 700;
  static Color background = const Color(0xFF1E1E1E);
  static Color panel = const Color(0xFF252526);
  static Color sidebar = const Color(0xFF181818);
  static Color border = const Color(0xFF2B2B2B);
  static Color tabActive = const Color(0xFF1F1F1F);
  static Color tabInactive = const Color(0xFF2D2D2D);
  static Color tabHover = const Color(0xFF373737);
  static Color textPrimary = const Color(0xFFE6E6E6);
  static Color textMuted = const Color(0xFF9D9D9D);
  static Color accent = const Color(0xFF3794FF);
  static Color selection = const Color(0xFF094771);

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
  }

  static void applyTerminal(TerminalThemeSettings settings) {}
}
