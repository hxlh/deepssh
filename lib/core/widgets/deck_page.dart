import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_colors.dart';
import 'deck_widgets.dart';

/// Page scaffolding shared by the settings pages: eyebrow + serif title +
/// subtitle on the left, the single primary action on the right, an optional
/// toolbar, then the body.
class DeckPageScaffold extends StatelessWidget {
  const DeckPageScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const <Widget>[],
    this.toolbar,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? toolbar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DeckEyebrow(eyebrow),
                    DeckTitle(title, key: const ValueKey('deck-page-title')),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              for (final action in actions) ...[
                const SizedBox(width: 8),
                action,
              ],
            ],
          ),
          if (toolbar != null) ...[const SizedBox(height: 12), toolbar!],
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Bordered table. Columns are declared as flexible weights so a row can lay
/// itself out the same way as its header without a data table widget.
class DeckTable extends StatelessWidget {
  const DeckTable({
    super.key,
    required this.flexWeights,
    required this.headerLabels,
    required this.children,
    this.trailingWidth = 0,
    this.showHeader = true,
  });

  final List<int> flexWeights;
  final List<String> headerLabels;
  final List<Widget> children;

  /// The prototype's connection/tunnel lists start straight at the first row;
  /// the table header is only used where a column legend actually helps.
  final bool showHeader;

  /// Fixed width reserved for the row action column. It must not flex — the
  /// buttons would stretch and stop reading as buttons.
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.textPrimary),
        boxShadow: AppColors.shadowSolid,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.textPrimary),
                ),
              ),
              child: Row(
                children: [
                  for (var index = 0; index < headerLabels.length; index++)
                    Expanded(
                      flex: flexWeights[index],
                      child: DeckLabel(
                        headerLabels[index],
                        size: 9.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  if (trailingWidth > 0)
                    SizedBox(
                      width: trailingWidth,
                      child: const DeckLabel('操作'),
                    ),
                ],
              ),
            ),
          // The prototype's list hugs its rows; the page around it scrolls.
          // Shrink-wrapping here keeps a two-row table from drawing a
          // 700px-tall empty box.
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: children.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) => children[index],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single table row with a status-coloured left rule.
class DeckTableRow extends StatelessWidget {
  const DeckTableRow({
    super.key,
    required this.flexWeights,
    required this.statusColor,
    required this.cells,
    this.meta,
    this.trailing,
    this.trailingWidth = 0,
  });

  final List<int> flexWeights;
  final Color statusColor;
  final List<Widget> cells;

  /// The prototype's middle column: a small caption over a monospace value.
  final ({String label, String value})? meta;
  final Widget? trailing;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        child: Row(
          children: [
            for (var index = 0; index < cells.length; index++)
              Expanded(
                flex: flexWeights[index],
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: cells[index],
                ),
              ),
            if (meta != null)
              SizedBox(
                width: 210,
                child: DeckMetaCell(label: meta!.label, value: meta!.value),
              ),
            if (trailing != null)
              SizedBox(
                width: trailingWidth,
                child: Align(alignment: Alignment.centerRight, child: trailing),
              ),
          ],
        ),
      ),
    );
  }
}

/// Monospace value cell — hosts, ports and paths read better aligned.
class DeckMonoCell extends StatelessWidget {
  const DeckMonoCell(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: DeckTokens.fontMono,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      ),
    );
  }
}

/// Caption-over-value cell used for the table's middle column.
class DeckMetaCell extends StatelessWidget {
  const DeckMetaCell({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontFamilyFallback: DeckTokens.fontMono,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
