import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_colors.dart';

/// Shared primitives for the deck's visual language: zero radius, hard offset
/// shadows, pixel press, square status marks. Every interactive surface in the
/// app should come from here so the rules stay in one place.

/// Mono, uppercase, letter-spaced label — the app uses this for field names and
/// section headers only, never for body copy.
class DeckLabel extends StatelessWidget {
  const DeckLabel(
    this.text, {
    super.key,
    this.size = 10,
    this.color,
    this.spacing = 0.14,
    this.weight = FontWeight.w400,
  });

  final String text;
  final double size;
  final Color? color;

  /// Letter spacing in `em`, exactly as the prototype's CSS declares it
  /// (`.1em`–`.16em`). Converted to logical pixels at build time because
  /// Flutter's `letterSpacing` is absolute, not relative to the font size.
  final double spacing;

  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: DeckTokens.fontMono,
        fontSize: size,
        height: 1.2,
        letterSpacing: spacing * size,
        fontWeight: weight,
        color: color ?? AppColors.textMuted,
      ),
    );
  }
}

/// Serif page title. Reserved for page-level headings and empty-state copy.
class DeckTitle extends StatelessWidget {
  const DeckTitle(this.text, {super.key, this.size = 23});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: DeckTokens.fontDisplay,
        fontSize: size,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Small accent-coloured kicker above a page title.
class DeckEyebrow extends StatelessWidget {
  const DeckEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: DeckLabel(text, color: AppColors.accentInk, spacing: 0.16),
    );
  }
}

/// Square status mark. The prototype deliberately avoids circles so a status
/// reads the same at 7px and 10px.
class DeckStatusSquare extends StatelessWidget {
  const DeckStatusSquare(
    this.color, {
    super.key,
    this.size = 9,
    this.outlined = true,
  });

  final Color color;
  final double size;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        border: outlined
            ? Border.all(color: AppColors.textPrimary, width: 1)
            : null,
      ),
    );
  }
}

enum DeckButtonStyle { solid, accent, outline, ghost, danger }

/// The app's only button, matching the prototype's `.btn` computed styles:
/// 1px ink border, square corners, 12/7 padding (9/5 when [dense]), a 7px gap
/// and a 2px pixel-press with no resting shadow. `accent` maps to
/// `.btn-primary`, `ghost` to `.btn-ghost` and `danger` to `.btn-danger`.
class DeckButton extends StatefulWidget {
  const DeckButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = DeckButtonStyle.outline,
    this.icon,
    this.dense = false,
    this.destructive = false,
    this.iconOnly = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DeckButtonStyle style;
  final IconData? icon;
  final bool dense;
  final bool destructive;

  /// The prototype's `.btn.icon`: a 30x30 square carrying only the glyph
  /// (used by the drawer close button). [label] stays the semantics name.
  final bool iconOnly;

  @override
  State<DeckButton> createState() => _DeckButtonState();
}

class _DeckButtonState extends State<DeckButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final destructive =
        widget.destructive || widget.style == DeckButtonStyle.danger;

    final Color background;
    final Color foreground;
    final Color borderColor;
    switch (widget.style) {
      case DeckButtonStyle.solid:
        background = AppColors.textPrimary;
        foreground = AppColors.background;
        borderColor = AppColors.textPrimary;
      case DeckButtonStyle.accent:
        background = _hovered || _pressed
            ? AppColors.accentInk
            : AppColors.accent;
        foreground = AppColors.panel;
        borderColor = background;
      case DeckButtonStyle.ghost:
        background = _hovered ? AppColors.surfaceHover : Colors.transparent;
        foreground = destructive
            ? DeckTokens.danger
            : (_hovered ? AppColors.textPrimary : AppColors.textMuted);
        borderColor = Colors.transparent;
      case DeckButtonStyle.outline:
      case DeckButtonStyle.danger:
        background = _hovered ? AppColors.surfaceHover : AppColors.panel;
        foreground = destructive ? DeckTokens.danger : AppColors.textPrimary;
        borderColor = destructive
            ? DeckTokens.mix(DeckTokens.danger, AppColors.textPrimary, 0.45)
            : AppColors.textPrimary;
    }

    final ink = enabled ? foreground : AppColors.textMuted;
    final content = widget.iconOnly
        ? Icon(widget.icon ?? Icons.close, size: 14, color: ink)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 14, color: ink),
                const SizedBox(width: 7),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.dense ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ],
          );

    Widget surface = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      transform: _pressed
          ? (Matrix4.identity()..translateByDouble(2, 2, 0, 1))
          : Matrix4.identity(),
      padding: widget.iconOnly
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(
              horizontal: widget.dense ? 9 : 12,
              vertical: widget.dense ? 5 : 7,
            ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor),
      ),
      child: content,
    );
    if (widget.iconOnly) {
      surface = SizedBox(width: 30, height: 30, child: surface);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) {
          setState(() {
            _hovered = false;
            _pressed = false;
          });
        },
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: widget.onPressed,
          child: surface,
        ),
      ),
    );
  }
}

/// Bordered surface used for cards, lists and panels.
class DeckPanel extends StatelessWidget {
  const DeckPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    this.solid = false,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool solid;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: borderColor ?? AppColors.textPrimary),
        boxShadow: solid ? AppColors.shadowSolid : AppColors.shadowHard,
      ),
      child: child,
    );
  }
}

/// Mono uppercase badge with a tinted wash background.
class DeckBadge extends StatelessWidget {
  const DeckBadge(
    this.text, {
    super.key,
    this.foreground,
    this.background,
    this.borderColor,
    this.leading,
  });

  final String text;
  final Color? foreground;
  final Color? background;
  final Color? borderColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background ?? AppColors.background,
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 5)],
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: DeckTokens.fontMono,
              fontSize: 10,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w400,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status badge: a square mark plus a mono label. The prototype pairs the
/// square dot with words ("运行中" / "已停止") so status survives a narrow row
/// where the colour alone would not.
class DeckStatusBadge extends StatelessWidget {
  const DeckStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.background,
    this.borderColor,
  });

  final String label;
  final Color color;
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return DeckBadge(
      label,
      foreground: color,
      background: background,
      borderColor: borderColor,
      leading: DeckStatusSquare(color, size: 7, outlined: false),
    );
  }
}

/// Empty state shared by every list and panel.
class DeckEmptyState extends StatelessWidget {
  const DeckEmptyState({
    super.key,
    required this.title,
    this.hint,
    this.icon = Icons.inbox_outlined,
    this.dashed = true,
  });

  final String title;
  final String? hint;
  final IconData icon;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(
          color: dashed ? AppColors.border : AppColors.textPrimary,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: AppColors.textMuted),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontFamilyFallback: DeckTokens.fontDisplay,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 9),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.55,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Theme-wide input decoration: mono, square, hairline border that darkens on
/// focus. Every text field and dropdown in the app routes through this so the
/// "no radius" rule can't be forgotten.
InputDecorationTheme deckInputTheme() {
  InputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(color: color),
  );

  return InputDecorationTheme(
    filled: true,
    fillColor: AppColors.panel,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.textPrimary),
    errorBorder: border(DeckTokens.danger),
    focusedErrorBorder: border(DeckTokens.danger),
    labelStyle: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: DeckTokens.fontMono,
      fontSize: 10,
      letterSpacing: 1.0,
      color: AppColors.textMuted,
    ),
    floatingLabelStyle: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: DeckTokens.fontMono,
      fontSize: 10,
      letterSpacing: 1.0,
      color: AppColors.textPrimary,
    ),
    hintStyle: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: DeckTokens.fontMono,
      fontSize: 12,
      color: AppColors.textMuted,
    ),
    prefixIconColor: AppColors.textMuted,
    suffixIconColor: AppColors.textMuted,
  );
}

/// Square modal panel matching the prototype's `.dialog`: 440px, hard border,
/// hard offset shadow, serif title and a right-aligned action row.
class DeckDialog extends StatelessWidget {
  const DeckDialog({
    super.key,
    required this.title,
    required this.actions,
    this.message,
    this.child,
  });

  final String title;
  final String? message;
  final Widget? child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.textPrimary),
          boxShadow: AppColors.shadowSolid,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontFamilyFallback: DeckTokens.fontDisplay,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ],
            if (child != null) ...[const SizedBox(height: 14), child!],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  actions[index],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
