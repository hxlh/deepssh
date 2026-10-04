import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

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
    fillColor: DeckTokens.surface,
    // The prototype's `placeholder` is decorative: the stacked label already
    // names the field. Left as `hintText` it would concatenate onto the
    // field's semantics label and take the field's name with it.
    hint: hint == null
        ? null
        : ExcludeSemantics(
            child: Text(
              hint,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: DeckTokens.fontMono,
                fontSize: 12,
                color: DeckTokens.muted,
              ),
            ),
          ),
    hintStyle: const TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: DeckTokens.fontMono,
      fontSize: 12,
      color: DeckTokens.muted,
    ),
    contentPadding: content,
    border: _border(DeckTokens.border),
    enabledBorder: _border(DeckTokens.border),
    focusedBorder: _border(DeckTokens.fg),
    errorBorder: _border(DeckTokens.danger),
    focusedErrorBorder: _border(DeckTokens.danger),
    errorStyle: const TextStyle(fontSize: 11, color: DeckTokens.danger),
  );

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: color),
  );

  static const TextStyle text = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontFamilyFallback: DeckTokens.fontMono,
    fontSize: 12,
    color: DeckTokens.fg,
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
            style: const TextStyle(fontSize: 11, color: DeckTokens.muted),
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
      style: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: DeckTokens.fontMono,
        fontSize: 10,
        letterSpacing: 1.0,
        height: 1.2,
        color: DeckTokens.muted,
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
        onFieldSubmitted: onSubmitted,
        validator: validator,
      ),
    );
  }
}

/// Labelled dropdown with the same flat styling.
class DeckSelect<T> extends StatelessWidget {
  const DeckSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.focusNode,
    this.hint,
    this.itemBuilder,
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final FocusNode? focusNode;
  final String? hint;

  /// Lets a caller keep long option names from overflowing.
  final Widget Function(BuildContext, T)? itemBuilder;

  @override
  Widget build(BuildContext context) {
    return DeckField(
      label: label,
      hint: hint,
      child: InputDecorator(
        isEmpty: false,
        isFocused: false,
        decoration: DeckFieldStyle.decoration().copyWith(
          contentPadding: const EdgeInsets.fromLTRB(10, 8, 28, 8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            focusNode: focusNode,
            value: value,
            isExpanded: true,
            isDense: true,
            icon: const Icon(Icons.arrow_drop_down, size: 16),
            style: DeckFieldStyle.text,
            borderRadius: BorderRadius.zero,
            items: [
              for (final item in items)
                DropdownMenuItem<T>(
                  value: item,
                  child: itemBuilder?.call(context, item) ?? Text('$item'),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
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
