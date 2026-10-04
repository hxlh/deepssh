import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';
import 'deck_widgets.dart';

/// Right-hand drawer used for the SSH / port-forwarding forms.
///
/// The prototype draws these as a fixed overlay (`position:fixed; inset:0`)
/// rather than a page of their own: the list stays mounted behind the scrim so
/// closing the drawer lands the user back exactly where they were.
class DeckDrawer extends StatelessWidget {
  const DeckDrawer({
    super.key,
    required this.kicker,
    required this.title,
    required this.onClose,
    required this.child,
    required this.footer,
  });

  /// Small uppercase mono label above the title (`Port Forwarding`).
  final String kicker;
  final String title;

  /// Called by the scrim tap, the close button and Escape.
  final VoidCallback onClose;

  final Widget child;
  final Widget footer;

  static const double maxWidth = 430;

  @override
  Widget build(BuildContext context) {
    // Self-sizing rather than Positioned.fill so the drawer drops into any
    // host — a Stack layer over the shell, or a Scaffold body in a test.
    return SizedBox.expand(
      child: Shortcuts(
        // The prototype closes the drawer on Escape from anywhere.
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): _DismissIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _DismissIntent: CallbackAction<_DismissIntent>(
              onInvoke: (_) {
                onClose();
                return null;
              },
            ),
          },
          child: _buildPanel(context),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: ColoredBox(color: DeckTokens.wash(DeckTokens.fg, 0.34)),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            // Prototype: `width: min(430px, 100%)`. Without an explicit width
            // a loose-aligned Column would shrink to its content.
            width: math.min(maxWidth, MediaQuery.sizeOf(context).width),
            child: Container(
              decoration: BoxDecoration(
                color: DeckTokens.surface,
                border: Border(left: BorderSide(color: DeckTokens.fg)),
                // Hard shadow thrown to the left, matching the prototype's
                // `-2px 0 0` — no blur, no spread.
                boxShadow: [
                  BoxShadow(
                    color: DeckTokens.wash(DeckTokens.fg, 0.20),
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Head(kicker: kicker, title: title, onClose: onClose),
                  Expanded(child: child),
                  _Foot(footer),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({
    required this.kicker,
    required this.title,
    required this.onClose,
  });

  final String kicker;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DeckTokens.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DeckLabel(kicker, size: 10, spacing: 0.14),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontFamilyFallback: DeckTokens.fontDisplay,
                    fontSize: 17,
                    height: 1.15,
                    color: DeckTokens.fg,
                  ),
                ),
              ],
            ),
          ),
          DeckButton(
            label: '关闭',
            style: DeckButtonStyle.ghost,
            icon: Icons.close,
            dense: true,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _Foot extends StatelessWidget {
  const _Foot(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: DeckTokens.border)),
      ),
      child: child,
    );
  }
}

/// The scrollable body of a drawer. Children stack with the prototype's 15px
/// rhythm; wrap groups in [DeckFormSection] or a `Row` for the grid rows.
class DeckDrawerBody extends StatelessWidget {
  const DeckDrawerBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}
