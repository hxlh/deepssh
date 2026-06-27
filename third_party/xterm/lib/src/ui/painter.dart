import 'dart:ui';
import 'package:flutter/painting.dart';

import 'package:xterm/src/ui/palette_builder.dart';
import 'package:xterm/src/ui/paragraph_cache.dart';
import 'package:xterm/xterm.dart';

/// Encapsulates the logic for painting various terminal elements.
class TerminalPainter {
  TerminalPainter({
    required TerminalTheme theme,
    required TerminalStyle textStyle,
    required TextScaler textScaler,
  })  : _textStyle = textStyle,
        _theme = theme,
        _textScaler = textScaler;

  /// A lookup table from terminal colors to Flutter colors.
  late var _colorPalette = PaletteBuilder(_theme).build();

  /// Size of each character in the terminal.
  late var _cellSize = _measureCharSize();

  /// The cached for cells in the terminal. Should be cleared when the same
  /// cell no longer produces the same visual output. For example, when
  /// [_textStyle] is changed, or when the system font changes.
  final _paragraphCache = ParagraphCache(10240);

  TerminalStyle get textStyle => _textStyle;
  TerminalStyle _textStyle;
  set textStyle(TerminalStyle value) {
    if (value == _textStyle) return;
    _textStyle = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler = TextScaler.linear(1.0);
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  TerminalTheme get theme => _theme;
  TerminalTheme _theme;
  set theme(TerminalTheme value) {
    if (value == _theme) return;
    _theme = value;
    _colorPalette = PaletteBuilder(value).build();
    _paragraphCache.clear();
  }

  Size _measureCharSize() {
    const test = 'mmmmmmmmmm';

    final textStyle = _textStyle.toTextStyle();
    final builder = ParagraphBuilder(textStyle.getParagraphStyle());
    builder.pushStyle(
      textStyle.getTextStyle(textScaler: _textScaler),
    );
    builder.addText(test);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));

    final result = Size(
      paragraph.maxIntrinsicWidth / test.length,
      paragraph.height,
    );

    paragraph.dispose();
    return result;
  }

  /// The size of each character in the terminal.
  Size get cellSize => _cellSize;

  /// When the set of font available to the system changes, call this method to
  /// clear cached state related to font rendering.
  void clearFontCache() {
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  /// Paints the cursor based on the current cursor type.
  void paintCursor(
    Canvas canvas,
    Offset offset, {
    required TerminalCursorType cursorType,
    bool hasFocus = true,
  }) {
    final paint = Paint()
      ..color = _theme.cursor
      ..strokeWidth = 1;

    if (!hasFocus) {
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(offset & _cellSize, paint);
      return;
    }

    switch (cursorType) {
      case TerminalCursorType.block:
        paint.style = PaintingStyle.fill;
        canvas.drawRect(offset & _cellSize, paint);
        return;
      case TerminalCursorType.underline:
        return canvas.drawLine(
          Offset(offset.dx, offset.dy + _cellSize.height - 1),
          Offset(
            offset.dx + _cellSize.width,
            offset.dy + _cellSize.height - 1,
          ),
          paint,
        );
      case TerminalCursorType.verticalBar:
        return canvas.drawLine(
          Offset(offset.dx, offset.dy),
          Offset(offset.dx, offset.dy + _cellSize.height),
          paint,
        );
    }
  }

  @pragma('vm:prefer-inline')
  void paintHighlight(Canvas canvas, Offset offset, int length, Color color) {
    final endOffset =
        offset.translate(length * _cellSize.width, _cellSize.height);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    canvas.drawRect(
      Rect.fromPoints(offset, endOffset),
      paint,
    );
  }

  /// Paints [line] to [canvas] at [offset]. The x offset of [offset] is usually
  /// 0, and the y offset is the top of the line.
  void paintLine(
    Canvas canvas,
    Offset offset,
    BufferLine line, {
    List<Color?>? foregroundColors,
    int foregroundColorOffset = 0,
  }) {
    _paintLineBackgrounds(canvas, offset, line);
    _paintLineForegrounds(
      canvas,
      offset,
      line,
      foregroundColors: foregroundColors,
      foregroundColorOffset: foregroundColorOffset,
    );
  }

  /// The background color to paint for [cellData], or `null` when the cell uses
  /// the default background (nothing to draw). Inverse cells swap to the
  /// effective foreground color, matching [paintCellBackground].
  @pragma('vm:prefer-inline')
  Color? cellBackgroundColor(CellData cellData) {
    if (cellData.flags & CellFlags.inverse != 0) {
      return resolveForegroundColor(cellData.foreground);
    }
    final colorType = cellData.background & CellColor.typeMask;
    if (colorType == CellColor.normal) {
      return null;
    }
    return resolveBackgroundColor(cellData.background);
  }

  /// Paints the backgrounds of [line], merging horizontally-adjacent
  /// single-width cells that share the same resolved color into one
  /// [drawRect]. A full-screen TUI paints large flat regions (walls, carpet)
  /// where this turns thousands of per-cell rects per frame into a handful.
  /// Default-background cells paint nothing and merely break a run; wide
  /// (double-width) cells paint their own 2-wide rect and never merge, so the
  /// output is pixel-identical to the previous per-cell paint.
  void _paintLineBackgrounds(Canvas canvas, Offset offset, BufferLine line) {
    final cellData = CellData.empty();
    final cellWidth = _cellSize.width;
    final cellHeight = _cellSize.height;

    var runStart = 0;
    Color? runColor;

    void flushRun(int endExclusive) {
      final color = runColor;
      if (color == null || endExclusive <= runStart) return;
      canvas.drawRect(
        offset.translate(runStart * cellWidth, 0) &
            Size((endExclusive - runStart) * cellWidth + 1, cellHeight),
        Paint()..color = color,
      );
    }

    var i = 0;
    while (i < line.length) {
      line.getCellData(i, cellData);
      final charWidth = cellData.content >> CellContent.widthShift;

      if (charWidth == 2) {
        flushRun(i);
        final color = cellBackgroundColor(cellData);
        if (color != null) {
          canvas.drawRect(
            offset.translate(i * cellWidth, 0) &
                Size(cellWidth * 2 + 1, cellHeight),
            Paint()..color = color,
          );
        }
        runColor = null;
        runStart = i + 2;
        i += 2;
        continue;
      }

      final color = cellBackgroundColor(cellData);
      if (color != runColor) {
        flushRun(i);
        runStart = i;
        runColor = color;
      }
      i++;
    }
    flushRun(line.length);
  }

  void _paintLineForegrounds(
    Canvas canvas,
    Offset offset,
    BufferLine line, {
    List<Color?>? foregroundColors,
    int foregroundColorOffset = 0,
  }) {
    final cellData = CellData.empty();
    final cellWidth = _cellSize.width;

    for (var i = 0; i < line.length; i++) {
      line.getCellData(i, cellData);

      final charWidth = cellData.content >> CellContent.widthShift;
      final cellOffset = offset.translate(i * cellWidth, 0);
      final foregroundColor = foregroundColors == null
          ? null
          : foregroundColors[foregroundColorOffset + i];

      paintCellForeground(canvas, cellOffset, cellData,
          foregroundColor: foregroundColor);

      if (charWidth == 2) {
        i++;
      }
    }
  }

  @pragma('vm:prefer-inline')
  void paintCell(
    Canvas canvas,
    Offset offset,
    CellData cellData, {
    Color? foregroundColor,
  }) {
    paintCellBackground(canvas, offset, cellData);
    paintCellForeground(canvas, offset, cellData,
        foregroundColor: foregroundColor);
  }

  /// Paints the character in the cell represented by [cellData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellForeground(
    Canvas canvas,
    Offset offset,
    CellData cellData, {
    Color? foregroundColor,
  }) {
    final charCode = cellData.content & CellContent.codepointMask;
    if (charCode == 0) return;

    final cellFlags = cellData.flags;

    // A paragraph encodes only the glyph and its foreground color — never the
    // cell background, which is painted as a separate rect. Resolve the
    // effective color once and key the cache on it (plus the glyph and the
    // style bits that actually affect shaping) instead of on the raw cell
    // fields. The previous key folded in the background, so a glyph repeated
    // across many truecolor backgrounds (a full-screen half-block TUI) missed
    // the cache on nearly every cell every frame and rebuilt a Paragraph each
    // time.
    final baseColor = foregroundColor ??
        (cellFlags & CellFlags.inverse == 0
            ? resolveForegroundColor(cellData.foreground)
            : resolveBackgroundColor(cellData.background));
    final color = cellFlags & CellFlags.faint != 0
        ? baseColor.withOpacity(0.5)
        : baseColor;

    final cacheKey = Object.hash(charCode, cellFlags, color, _textScaler);
    var paragraph = _paragraphCache.getLayoutFromCache(cacheKey);

    if (paragraph == null) {
      final style = _textStyle.toTextStyle(
        color: color,
        bold: cellFlags & CellFlags.bold != 0,
        italic: cellFlags & CellFlags.italic != 0,
        underline: cellFlags & CellFlags.underline != 0,
      );

      // Flutter does not draw an underline below a space which is not between
      // other regular characters. As only single characters are drawn, this
      // will never produce an underline below a space in the terminal. As a
      // workaround the regular space CodePoint 0x20 is replaced with
      // the CodePoint 0xA0. This is a non breaking space and a underline can be
      // drawn below it.
      var char = String.fromCharCode(charCode);
      if (cellFlags & CellFlags.underline != 0 && charCode == 0x20) {
        char = String.fromCharCode(0xA0);
      }

      paragraph = _paragraphCache.performAndCacheLayout(
        char,
        style,
        _textScaler,
        cacheKey,
      );
    }

    canvas.drawParagraph(paragraph, offset);
  }

  /// Paints the background of a cell represented by [cellData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellBackground(Canvas canvas, Offset offset, CellData cellData) {
    late Color color;
    final colorType = cellData.background & CellColor.typeMask;

    if (cellData.flags & CellFlags.inverse != 0) {
      color = resolveForegroundColor(cellData.foreground);
    } else if (colorType == CellColor.normal) {
      return;
    } else {
      color = resolveBackgroundColor(cellData.background);
    }

    final paint = Paint()..color = color;
    final doubleWidth = cellData.content >> CellContent.widthShift == 2;
    final widthScale = doubleWidth ? 2 : 1;
    final size = Size(_cellSize.width * widthScale + 1, _cellSize.height);
    canvas.drawRect(offset & size, paint);
  }

  /// Get the effective foreground color for a cell from information encoded in
  /// [cellColor].
  @pragma('vm:prefer-inline')
  Color resolveForegroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.foreground;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  /// Get the effective background color for a cell from information encoded in
  /// [cellColor].
  @pragma('vm:prefer-inline')
  Color resolveBackgroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.background;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }
}
