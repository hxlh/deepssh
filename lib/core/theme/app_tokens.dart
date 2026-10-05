import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Design tokens for the "warm paper / terracotta" deck.
///
/// The six base tokens are locked; every other colour in the app is derived
/// through [mix] so the visual language stays coherent. The prototype derives
/// its washes with `color-mix(in oklch, ...)`, so mixing happens in OKLab
/// rather than sRGB — otherwise a 14% terracotta wash turns muddy and shifts
/// per channel.
abstract final class DeckTokens {
  // Base palette (locked).
  static const Color bg = Color(0xFFFAF9F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color fg = Color(0xFF1F1E1D);
  static const Color muted = Color(0xFF6B6862);
  static const Color border = Color(0xFFE9E5DA);
  static const Color accent = Color(0xFFD97757);

  // Status.
  static const Color ok = Color(0xFF4E7A4E);
  static const Color warn = Color(0xFF8A6414);
  static const Color warnBar = Color(0xFFC08A2E);
  static const Color danger = Color(0xFFB0523A);

  // The terminal stays dark on purpose: a dark stage inside light chrome is
  // what separates "the terminal" from "the tool around it".
  static const Color termBg = Color(0xFF17181A);
  static const Color termFg = Color(0xFFDEDCD6);
  static const Color termDim = Color(0xFF86847C);
  static const Color termGreen = Color(0xFF8FBF7F);
  static const Color termBlue = Color(0xFF7FA8D8);
  static const Color termAmber = Color(0xFFD9A24B);
  static const Color termRed = Color(0xFFD98C7A);
  static const Color termCyan = Color(0xFF6FB6B0);

  // Derived washes.
  static Color get accentInk => mix(accent, fg, 0.68);
  static Color get accentSoft => wash(accent, 0.14);
  static Color get okSoft => wash(ok, 0.12);
  static Color get warnSoft => wash(warnBar, 0.20);
  static Color get dangerSoft => wash(danger, 0.12);
  static Color get fgSoft => wash(fg, 0.06);
  static Color get borderStrong => mix(border, fg, 0.35);

  /// Hard shadow for clickable cards and floating layers.
  /// Shadows are disabled app-wide: flat borders only, no drop shadow.
  static List<BoxShadow> get shadowHard => const <BoxShadow>[];

  /// Opaque hard shadow for dialogs and drawers.
  static List<BoxShadow> get shadowSolid => const <BoxShadow>[];

  // Typography. Serif is reserved for page titles and empty-state copy; mono
  // is for labels, fields and numbers only.
  static const List<String> fontDisplay = <String>[
    'Georgia',
    'Iowan Old Style',
    'Charter',
    'Times New Roman',
    'Noto Sans SC',
  ];
  static const List<String> fontBody = <String>[
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans SC',
  ];
  static const List<String> fontMono = <String>[
    'JetBrains Mono',
    'SF Mono',
    'Menlo',
    'Consolas',
    'Noto Sans SC',
  ];

  /// Mixes [a] toward [b] by [amount] in OKLab space.
  ///
  /// For tinting a colour toward its own background pass the background as [b];
  /// [wash] is the shorthand for the common "faint version of this" case.
  static Color mix(Color a, Color b, double amount) {
    final ratio = amount.clamp(0.0, 1.0);
    if (ratio == 0) return a;
    if (ratio == 1) return b;
    final labA = _toOkLab(a);
    final labB = _toOkLab(b);
    return _fromOkLab(
      _Lab(
        labA.l + (labB.l - labA.l) * ratio,
        labA.a + (labB.a - labA.a) * ratio,
        labA.b + (labB.b - labA.b) * ratio,
      ),
      a.a + (b.a - a.a) * ratio,
    );
  }

  /// Returns [color] at [opacity] alpha — a faint version of itself.
  static Color wash(Color color, double opacity) =>
      color.withValues(alpha: opacity);

  /// Mixes toward a lighter version of the same hue, so a hover state reads as
  /// "the same surface, lit" instead of a different colour.
  static Color lighten(Color color, double amount) {
    final lab = _toOkLab(color);
    return _fromOkLab(_Lab(lab.l + amount, lab.a, lab.b), color.a);
  }

  /// Mixes toward a darker version of the same hue.
  static Color darken(Color color, double amount) {
    final lab = _toOkLab(color);
    return _fromOkLab(_Lab(lab.l - amount, lab.a, lab.b), color.a);
  }
}

class _Lab {
  const _Lab(this.l, this.a, this.b);
  final double l;
  final double a;
  final double b;
}

_Lab _toOkLab(Color color) {
  final r = _srgbToLinear(color.r);
  final g = _srgbToLinear(color.g);
  final b = _srgbToLinear(color.b);

  final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
  final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
  final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

  final lRoot = _cbrt(l);
  final mRoot = _cbrt(m);
  final sRoot = _cbrt(s);

  return _Lab(
    0.2104542553 * lRoot + 0.7936177850 * mRoot - 0.0040720468 * sRoot,
    1.9779984951 * lRoot - 2.4285922050 * mRoot + 0.4505937099 * sRoot,
    0.0259040371 * lRoot + 0.7827717662 * mRoot - 0.8086757660 * sRoot,
  );
}

Color _fromOkLab(_Lab lab, double alpha) {
  final lPrime = lab.l + 0.3963377774 * lab.a + 0.2158037573 * lab.b;
  final mPrime = lab.l - 0.1055613458 * lab.a - 0.0638541728 * lab.b;
  final sPrime = lab.l - 0.0894841775 * lab.a - 1.2914855480 * lab.b;

  final l = lPrime * lPrime * lPrime;
  final m = mPrime * mPrime * mPrime;
  final s = sPrime * sPrime * sPrime;

  final r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  final g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  final b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

  return Color.fromRGBO(
    _linearToSrgb(r),
    _linearToSrgb(g),
    _linearToSrgb(b),
    alpha,
  );
}

double _srgbToLinear(double channel) {
  if (channel <= 0.04045) return channel / 12.92;
  return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

int _linearToSrgb(double channel) {
  final value = channel <= 0.0031308
      ? channel * 12.92
      : 1.055 * math.pow(channel, 1 / 2.4).toDouble() - 0.055;
  return (value.clamp(0.0, 1.0) * 255).round();
}

double _cbrt(double value) {
  if (value < 0) return -_cbrt(-value);
  return math.pow(value, 1 / 3).toDouble();
}
