import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// One toast channel per overlay. The prototype stacks simultaneous toasts in
/// a bottom-centred column with an 8px gap (`.toast-wrap`), so each entry owns
/// the whole column instead of fighting with the others for `bottom: 18`.
final Map<OverlayState, _ToastChannel> _channels =
    <OverlayState, _ToastChannel>{};

/// Bottom-centred toast matching the prototype's `.toast`: ink panel, paper
/// text, green 7px dot, hard shadow and the 160ms rise-in. Toasts live 2600ms.
void showDeckToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  // Drop channels whose overlay is gone (app teardown, test pumpWidget) so
  // this map cannot keep dead element trees alive.
  _channels.removeWhere((state, _) => !state.mounted);
  _channels.putIfAbsent(overlay, () => _ToastChannel(overlay)).push(message);
}

class _ToastMessage {
  const _ToastMessage(this.id, this.text);

  final int id;
  final String text;
}

class _ToastChannel {
  _ToastChannel(this._overlay) {
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        bottom: 18,
        child: IgnorePointer(
          child: ValueListenableBuilder<List<_ToastMessage>>(
            valueListenable: _messages,
            builder: (context, messages, _) => Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < messages.length; index++) ...[
                    if (index > 0) const SizedBox(height: 8),
                    _DeckToast(
                      // Keyed by message id: without it, expiring an earlier
                      // toast shifts the survivors one slot up and the reused
                      // element keeps the *previous* toast's state — whose
                      // timer already fired — so the survivor never expires.
                      key: ValueKey(messages[index].id),
                      // The toast owns its dismissal timer, so disposing the
                      // tree (tests, app shutdown) cancels it instead of
                      // leaving a pending timer behind.
                      message: messages[index].text,
                      onExpired: () => _remove(messages[index].id),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    _overlay.insert(_entry);
  }

  final OverlayState _overlay;
  late final OverlayEntry _entry;
  final ValueNotifier<List<_ToastMessage>> _messages =
      ValueNotifier<List<_ToastMessage>>(const <_ToastMessage>[]);
  int _nextId = 0;

  void push(String text) {
    final id = _nextId++;
    _messages.value = <_ToastMessage>[
      ..._messages.value,
      _ToastMessage(id, text),
    ];
  }

  void _remove(int id) {
    _messages.value = <_ToastMessage>[
      for (final message in _messages.value)
        if (message.id != id) message,
    ];
    if (_messages.value.isEmpty) {
      if (_entry.mounted) _entry.remove();
      _channels.remove(_overlay);
      _messages.dispose();
    }
  }
}

class _DeckToast extends StatefulWidget {
  const _DeckToast({super.key, required this.message, required this.onExpired});

  final String message;
  final VoidCallback onExpired;

  @override
  State<_DeckToast> createState() => _DeckToastState();
}

class _DeckToastState extends State<_DeckToast> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2600), widget.onExpired);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          border: Border.all(color: AppColors.textPrimary),
          boxShadow: AppColors.shadowHard,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, color: DeckTokens.termGreen),
            const SizedBox(width: 9),
            Text(
              widget.message,
              // Overlay entries do not sit under the page's DefaultTextStyle,
              // so name the deck UI font explicitly or the label falls back
              // to the platform font (yellow debug underline in dev builds).
              style: TextStyle(
                fontFamily: AppColors.fontFamilyPrimary,
                fontFamilyFallback: AppColors.fontFamilyFallback,
                fontSize: 12,
                color: AppColors.background,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
