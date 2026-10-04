import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

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
  });

  final String text;
  final double size;
  final Color? color;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: DeckTokens.fontMono,
        fontSize: size,
        height: 1.2,
        letterSpacing: spacing,
        fontWeight: FontWeight.w600,
        color: color ?? DeckTokens.muted,
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
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: DeckTokens.fg,
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
      child: DeckLabel(text, color: DeckTokens.accentInk, spacing: 0.16),
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
        border: outlined ? Border.all(color: DeckTokens.fg, width: 1) : null,
      ),
    );
  }
}

enum DeckButtonStyle { solid, outline, ghost, danger }

/// The app's only button. `solid` is reserved for the single primary action on
/// a screen — a row never shows two of them.
class DeckButton extends StatefulWidget {
  const DeckButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = DeckButtonStyle.outline,
    this.icon,
    this.dense = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DeckButtonStyle style;
  final IconData? icon;
  final bool dense;
  final bool destructive;

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
    if (widget.style == DeckButtonStyle.solid) {
      background = _pressed ? DeckTokens.darken(DeckTokens.fg, 0.04) : DeckTokens.fg;
      foreground = DeckTokens.bg;
      borderColor = DeckTokens.fg;
    } else if (widget.style == DeckButtonStyle.ghost) {
      background = _hovered ? DeckTokens.fgSoft : Colors.transparent;
      foreground = destructive ? DeckTokens.danger : DeckTokens.fg;
      borderColor = Colors.transparent;
    } else {
      background = _hovered ? DeckTokens.fgSoft : DeckTokens.surface;
      foreground = destructive ? DeckTokens.danger : DeckTokens.fg;
      borderColor = _hovered ? DeckTokens.fg : DeckTokens.border;
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: widget.dense ? 12 : 13, color: foreground),
          const SizedBox(width: 6),
        ],
        Text(
          widget.label,
          style: TextStyle(
            fontSize: widget.dense ? 11.5 : 12,
            fontWeight: FontWeight.w600,
            color: enabled ? foreground : DeckTokens.muted,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: MouseRegion(
        cursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            transform: _pressed
                ? (Matrix4.identity()..translateByDouble(1, 1, 0, 1))
                : Matrix4.identity(),
            padding: EdgeInsets.symmetric(
              horizontal: widget.dense ? 8 : 11,
              vertical: widget.dense ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: borderColor),
              boxShadow: _pressed || !enabled
                  ? null
                  : DeckTokens.shadowSolid,
            ),
            child: content,
          ),
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
    this.padding = const EdgeInsets.all(16),
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
        color: DeckTokens.surface,
        border: Border.all(color: borderColor ?? DeckTokens.fg),
        boxShadow: solid ? DeckTokens.shadowSolid : DeckTokens.shadowHard,
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
    final fg = foreground ?? DeckTokens.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background ?? DeckTokens.bg,
        border: Border.all(color: borderColor ?? DeckTokens.border),
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
              letterSpacing: 0.06,
              fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(
          color: dashed ? DeckTokens.border : DeckTokens.fg,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: DeckTokens.muted),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontFamilyFallback: DeckTokens.fontDisplay,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DeckTokens.fg,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 7),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.55,
                color: DeckTokens.muted,
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
    fillColor: DeckTokens.surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: border(DeckTokens.border),
    enabledBorder: border(DeckTokens.border),
    focusedBorder: border(DeckTokens.fg),
    errorBorder: border(DeckTokens.danger),
    focusedErrorBorder: border(DeckTokens.danger),
    labelStyle: const TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: DeckTokens.fontMono,
      fontSize: 10,
      letterSpacing: 0.1,
      color: DeckTokens.muted,
    ),
    floatingLabelStyle: const TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: DeckTokens.fontMono,
      fontSize: 10,
      letterSpacing: 0.1,
      color: DeckTokens.fg,
    ),
    hintStyle: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: DeckTokens.fontMono,
      fontSize: 12,
      color: DeckTokens.muted.withValues(alpha: 0.85),
    ),
    prefixIconColor: DeckTokens.muted,
    suffixIconColor: DeckTokens.muted,
  );
}
