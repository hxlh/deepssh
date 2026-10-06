import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The prototype's single `openCtx()` menu, shared by every surface that
/// carries a context menu (the Explorer tree, the tab strip): paper-on-ink,
/// square, no elevation, and a 3px accent rail on the hovered entry.
const double deckMenuWidth = 150;
const double deckMenuItemHeight = 32;

/// One entry of a [showDeckContextMenu] menu.
class DeckMenuItem {
  const DeckMenuItem({required this.value, required this.label});

  final String value;
  final String label;
}

/// Opens the deck-styled context menu at [globalPosition] and resolves to the
/// chosen item's value, or null when the menu is dismissed.
Future<String?> showDeckContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required List<DeckMenuItem> items,
  double width = deckMenuWidth,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    color: AppColors.panel,
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    menuPadding: EdgeInsets.zero,
    constraints: BoxConstraints.tightFor(width: width),
    clipBehavior: Clip.none,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
      side: BorderSide(color: AppColors.textPrimary),
    ),
    items: [
      for (final item in items)
        PopupMenuItem<String>(
          value: item.value,
          height: deckMenuItemHeight,
          padding: EdgeInsets.zero,
          child: DeckContextMenuItem(label: item.label, width: width),
        ),
    ],
  );
}

/// Menu row with the prototype's hover treatment: soft wash, a heavier label,
/// and the accent rail on the left edge.
class DeckContextMenuItem extends StatefulWidget {
  const DeckContextMenuItem({
    super.key,
    required this.label,
    this.width = deckMenuWidth,
  });

  final String label;
  final double width;

  @override
  State<DeckContextMenuItem> createState() => _DeckContextMenuItemState();
}

class _DeckContextMenuItemState extends State<DeckContextMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        width: widget.width,
        height: deckMenuItemHeight,
        color: _hovered ? AppColors.fgSoft : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 3,
              height: double.infinity,
              color: _hovered ? AppColors.accent : Colors.transparent,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: _hovered ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
