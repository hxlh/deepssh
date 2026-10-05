import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';
import '../theme/app_colors.dart';

/// Form controls for the drawer forms.
///
/// The prototype does not use Material's floating labels: every field is a
/// small uppercase mono label stacked over a flat, square input. Keeping the
/// label as a separate node also means `find.bySemanticsLabel` still works,
/// which the form tests rely on.
abstract final class DeckFieldStyle {
  static const EdgeInsets content = EdgeInsets.fromLTRB(10, 8, 10, 8);
  static const BorderRadius radius = BorderRadius.zero;

  static InputDecoration decoration({String? hint}) => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: AppColors.panel,
    // The prototype's `placeholder` is decorative: the stacked label already
    // names the field. Left as `hintText` it would concatenate onto the
    // field's semantics label and take the field's name with it.
    hint: hint == null
        ? null
        : ExcludeSemantics(
            child: Text(
              hint,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: DeckTokens.fontMono,
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
    hintStyle: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: DeckTokens.fontMono,
      fontSize: 12,
      color: AppColors.textMuted,
    ),
    contentPadding: content,
    border: _border(AppColors.border),
    enabledBorder: _border(AppColors.border),
    focusedBorder: _border(AppColors.textPrimary),
    errorBorder: _border(DeckTokens.danger),
    focusedErrorBorder: _border(DeckTokens.danger),
    errorStyle: const TextStyle(fontSize: 11, color: DeckTokens.danger),
  );

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: color),
  );

  static TextStyle text = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontFamilyFallback: DeckTokens.fontMono,
    fontSize: 12,
    color: AppColors.textPrimary,
  );
}

/// Label + control, stacked the way the prototype's `.field` does.
class DeckField extends StatelessWidget {
  const DeckField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final Widget child;

  /// Small muted note under the control (prototype `.hint`).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The visible label is decorative for a11y: the semantics label rides
        // on the control itself, the way the prototype's <label for> does.
        ExcludeSemantics(child: DeckFieldLabel(label)),
        const SizedBox(height: 5),
        Semantics(label: label, container: true, child: child),
        if (hint != null) ...[
          const SizedBox(height: 5),
          Text(
            hint!,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class DeckFieldLabel extends StatelessWidget {
  const DeckFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: DeckTokens.fontMono,
        fontSize: 10,
        letterSpacing: 1.0,
        height: 1.2,
        color: AppColors.textMuted,
      ),
    );
  }
}

/// Labelled text input carrying the prototype's placeholder.
class DeckTextField extends StatelessWidget {
  const DeckTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.hintText,
    this.focusNode,
    this.keyboardType,
    this.inputFormatters,
    this.obscure = false,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enableSuggestions = false,
    this.autocorrect = false,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;

  /// Placeholder shown inside the input (prototype `placeholder`).
  final String? hintText;

  /// Note under the input (prototype `.hint`).
  final String? hint;

  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final bool enableSuggestions;
  final bool autocorrect;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return DeckField(
      label: label,
      hint: hint,
      child: TextFormField(
        focusNode: focusNode,
        controller: controller,
        style: DeckFieldStyle.text,
        decoration: DeckFieldStyle.decoration(hint: hintText),
        obscureText: obscure,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textInputAction: textInputAction,
        enableSuggestions: enableSuggestions,
        autocorrect: autocorrect,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        validator: validator,
      ),
    );
  }
}

/// Labelled dropdown carrying the prototype's shared `.sel-*` language: a
/// flat `.input`-shaped trigger and a hand-built overlay (zero radius, 1px ink
/// border, hard offset shadow, 34px rows with a 3px accent bar on the current
/// row). The Material menu's rounded corners, blurred elevation and grey
/// selected row are exactly what §2.4 forbids, so it is not used here.
class DeckSelect<T> extends StatefulWidget {
  const DeckSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.focusNode,
    this.hint,
    this.itemBuilder,
  });

  /// Visible mono label above the trigger. Null for toolbar selects (the
  /// prototype's `#authFilter` carries an aria-label instead).
  final String? label;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final FocusNode? focusNode;
  final String? hint;

  /// Lets a caller keep long option names from overflowing.
  final Widget Function(BuildContext, T)? itemBuilder;

  @override
  State<DeckSelect<T>> createState() => _DeckSelectState<T>();
}

class _DeckSelectState<T> extends State<DeckSelect<T>> {
  final GlobalKey _triggerKey = GlobalKey();
  FocusNode? _internalFocus;
  OverlayEntry? _entry;
  bool _open = false;
  bool _focused = false;

  FocusNode get _focus => widget.focusNode ?? (_internalFocus ??= FocusNode());

  @override
  void dispose() {
    _removeEntry();
    _internalFocus?.dispose();
    super.dispose();
  }

  Widget _labelFor(BuildContext context, T item) =>
      widget.itemBuilder?.call(context, item) ?? Text('$item');

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  void _openMenu() {
    if (_open) return;
    final overlay = Overlay.maybeOf(context);
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null || box == null) return;

    final rect = box.localToGlobal(Offset.zero) & box.size;
    final screen = MediaQuery.sizeOf(context);
    final wanted = widget.items.length * _DeckSelectMenu.rowHeight + 8;
    final menuHeight = wanted < _DeckSelectMenu.maxHeight
        ? wanted
        : _DeckSelectMenu.maxHeight;
    final below = screen.height - rect.bottom - 4;
    final above = rect.top - 4;
    final openUp = below < menuHeight && above > below;

    var highlighted = widget.items.indexOf(widget.value);
    if (highlighted < 0) highlighted = 0;

    setState(() => _open = true);
    _entry = OverlayEntry(
      builder: (context) => _DeckSelectMenu<T>(
        triggerRect: rect,
        screenHeight: screen.height,
        openUp: openUp,
        initialHighlight: highlighted,
        items: widget.items,
        selected: widget.value,
        itemBuilder: _labelFor,
        onPick: _pick,
        onDismiss: _closeMenu,
      ),
    );
    overlay.insert(_entry!);
  }

  void _closeMenu() {
    if (!_open) return;
    _removeEntry();
    if (mounted) setState(() => _open = false);
    if (_focus.canRequestFocus) _focus.requestFocus();
  }

  void _pick(T item) {
    _removeEntry();
    if (mounted) setState(() => _open = false);
    if (!identical(item, widget.value)) widget.onChanged(item);
    if (_focus.canRequestFocus) _focus.requestFocus();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.arrowDown:
        _openMenu();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _openMenu();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // The trigger mirrors `.input`/`.sel-trigger`: 8/10 padding, 1px border
    // that turns ink when focused or expanded, and a 11px caret that flips.
    final Widget trigger = Focus(
      focusNode: _focus,
      onKeyEvent: _handleKey,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: GestureDetector(
        key: _triggerKey,
        behavior: HitTestBehavior.opaque,
        onTap: _open ? _closeMenu : _openMenu,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.panel,
              border: Border.all(
                color: _focused || _open
                    ? AppColors.textPrimary
                    : AppColors.border,
              ),
              boxShadow: _open ? AppColors.shadowHard : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: DeckFieldStyle.text.copyWith(
                      overflow: TextOverflow.ellipsis,
                    ),
                    child: _labelFor(context, widget.value),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 12,
                    color: _open || _focused
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final label = widget.label;
    if (label == null) {
      // Toolbar select: no visible label, but keep the a11y name.
      return Semantics(
        label: widget.hint ?? '',
        container: true,
        child: trigger,
      );
    }
    return DeckField(label: label, hint: widget.hint, child: trigger);
  }
}

/// The floating option panel. Lives in the root overlay so a scrolling drawer
/// can never clip it, and flips above the trigger when the space below is too
/// tight — the two positioning rules §2.4 calls out.
class _DeckSelectMenu<T> extends StatefulWidget {
  const _DeckSelectMenu({
    required this.triggerRect,
    required this.screenHeight,
    required this.openUp,
    required this.initialHighlight,
    required this.items,
    required this.selected,
    required this.itemBuilder,
    required this.onPick,
    required this.onDismiss,
  });

  static const double rowHeight = 34;
  static const double maxHeight = 264;
  static const double gap = 4;

  final Rect triggerRect;
  final double screenHeight;
  final bool openUp;
  final int initialHighlight;
  final List<T> items;
  final T selected;
  final Widget Function(BuildContext, T) itemBuilder;
  final ValueChanged<T> onPick;
  final VoidCallback onDismiss;

  @override
  State<_DeckSelectMenu<T>> createState() => _DeckSelectMenuState<T>();
}

class _DeckSelectMenuState<T> extends State<_DeckSelectMenu<T>> {
  late int _highlight = widget.initialHighlight;
  int? _hovered;
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final next = (_highlight + delta).clamp(0, widget.items.length - 1);
    setState(() => _highlight = next);
    _reveal(next);
  }

  void _reveal(int index) {
    if (!_scroll.hasClients) return;
    final extent = _scroll.position.viewportDimension;
    final target = index * _DeckSelectMenu.rowHeight;
    final maxOffset = _scroll.position.maxScrollExtent;
    final clamped = target
        .clamp(0.0, maxOffset <= 0 ? 0.0 : maxOffset)
        .toDouble();
    if ((_scroll.offset - clamped).abs() < extent / 2) return;
    _scroll.animateTo(
      clamped,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
    );
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        setState(() => _highlight = 0);
        _reveal(0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        final last = widget.items.length - 1;
        setState(() => _highlight = last);
        _reveal(last);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.space:
        widget.onPick(widget.items[_highlight]);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.tab:
        widget.onDismiss();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rect = widget.triggerRect;
    final height = math.min<double>(
      _DeckSelectMenu.maxHeight,
      widget.items.length * _DeckSelectMenu.rowHeight + 8,
    );
    return Stack(
      children: [
        // Clicking anywhere outside dismisses; the panel keeps its own hits.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        Positioned(
          left: rect.left,
          width: rect.width,
          top: widget.openUp ? null : rect.bottom + _DeckSelectMenu.gap,
          bottom: widget.openUp
              ? widget.screenHeight - rect.top + _DeckSelectMenu.gap
              : null,
          child: Focus(
            autofocus: true,
            onKeyEvent: (_, event) => _handleKey(event),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                border: Border.all(color: AppColors.textPrimary),
                boxShadow: AppColors.shadowHard,
              ),
              padding: const EdgeInsets.all(4),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: height),
                child: ListView.builder(
                  controller: _scroll,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemExtent: _DeckSelectMenu.rowHeight,
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final selected = item == widget.selected;
                    final active = index == _highlight || index == _hovered;
                    return MouseRegion(
                      onEnter: (_) => setState(() => _hovered = index),
                      onExit: (_) => setState(() {
                        if (_hovered == index) _hovered = null;
                      }),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onPick(item),
                        child: Container(
                          height: _DeckSelectMenu.rowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: selected || active
                                ? AppColors.background
                                : null,
                            border: Border(
                              left: BorderSide(
                                color: selected
                                    ? AppColors.accent
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          alignment: Alignment.centerLeft,
                          child: DefaultTextStyle.merge(
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontFamilyFallback: DeckTokens.fontMono,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textPrimary,
                              overflow: TextOverflow.ellipsis,
                            ),
                            child: widget.itemBuilder(context, item),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Two fields side by side — the prototype's `.grid2`.
class DeckFieldRow extends StatelessWidget {
  const DeckFieldRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // No IntrinsicHeight: TextFormField reports an unhelpful intrinsic height,
    // and letting the two cells size independently keeps the error text from
    // stretching the whole row.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// Caps text fields to digits — the prototype marks ports `inputmode=numeric`.
TextInputFormatter digitsOnly() => FilteringTextInputFormatter.digitsOnly;
