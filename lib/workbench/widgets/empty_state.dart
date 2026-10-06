import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Shown in the terminal stage when no tab is active.
///
/// The prototype renders this as a single dim line inside the dark terminal
/// (`<pre class="terminal"><span class="t-dim">没有活动的会话…</span>`), not as a
/// centred card — an icon and two paragraphs would fight the terminal chrome it
/// sits inside. Matching the terminal's own padding, font and leading keeps the
/// stage looking untouched.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Text(
          '没有活动的会话。请从左侧资源管理器打开一个终端。',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontFamilyFallback: DeckTokens.fontMono,
            fontSize: 12.5,
            height: 1.62,
            color: DeckTokens.termDim,
          ),
        ),
      ),
    );
  }
}
