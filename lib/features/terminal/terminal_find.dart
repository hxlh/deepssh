import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../../core/theme/app_colors.dart';

class _FindMatch {
  const _FindMatch({
    required this.startRow,
    required this.start,
    required this.endRow,
    required this.end,
  });
  final int startRow;
  final int start;
  final int endRow;
  final int end;
}

class _SearchPosition {
  const _SearchPosition({
    required this.row,
    required this.column,
    required this.endColumn,
  });
  final int row;
  final int column;
  final int endColumn;
}

class _SearchBuffer {
  const _SearchBuffer({required this.text, required this.positions});
  final String text;
  final List<_SearchPosition> positions;
}

class TerminalFindSession {
  TerminalFindSession({
    required this.terminal,
    required this.terminalController,
    required this.searchHitBackground,
    required this.searchHitBackgroundCurrent,
  });

  final xterm.Terminal terminal;
  final xterm.TerminalController terminalController;
  final Color searchHitBackground;
  final Color searchHitBackgroundCurrent;

  String _query = '';
  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _useRegex = false;
  final List<_FindMatch> _matches = [];
  int _currentIndex = -1;
  final List<xterm.TerminalHighlight> _highlights = [];

  String get query => _query;
  bool get caseSensitive => _caseSensitive;
  bool get wholeWord => _wholeWord;
  bool get useRegex => _useRegex;
  int get currentIndex => _currentIndex;
  int get matchCount => _matches.length;

  int? get currentMatchRow {
    if (_currentIndex < 0 || _currentIndex >= _matches.length) return null;
    return _matches[_currentIndex].startRow;
  }

  void setCaseSensitive(bool value) {
    if (_caseSensitive == value) return;
    _caseSensitive = value;
    _search(_query);
  }

  void setWholeWord(bool value) {
    if (_wholeWord == value) return;
    _wholeWord = value;
    _search(_query);
  }

  void setUseRegex(bool value) {
    if (_useRegex == value) return;
    _useRegex = value;
    _search(_query);
  }

  void setQuery(String query) {
    _query = query.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    _search(_query);
  }

  void _search(String query) {
    _clearHighlights();
    _matches.clear();
    _currentIndex = -1;

    if (query.isEmpty) return;

    final pattern = _useRegex ? query : RegExp.escape(query);
    final prefix = _wholeWord ? r'\b' : '';
    final suffix = _wholeWord ? r'\b' : '';
    try {
      final regex = RegExp(
        '$prefix$pattern$suffix',
        caseSensitive: _caseSensitive,
      );

      final searchBuffer = _buildSearchBuffer();
      for (final match in regex.allMatches(searchBuffer.text)) {
        if (match.start == match.end) continue;
        final start = searchBuffer.positions[match.start];
        final end = searchBuffer.positions[match.end - 1];
        _matches.add(
          _FindMatch(
            startRow: start.row,
            start: start.column,
            endRow: end.row,
            end: end.endColumn,
          ),
        );
      }
    } on FormatException {
      // Invalid regex; leave matches empty.
    }

    if (_matches.isNotEmpty) {
      _currentIndex = 0;
      _createHighlights();
    }
  }

  _SearchBuffer _buildSearchBuffer() {
    final text = StringBuffer();
    final positions = <_SearchPosition>[];
    final lines = terminal.buffer.lines;
    for (var row = 0; row < lines.length; row++) {
      if (row > 0) {
        text.write('\n');
        positions.add(
          _SearchPosition(
            row: row - 1,
            column: lines[row - 1].length,
            endColumn: lines[row - 1].length,
          ),
        );
      }
      final line = lines[row];
      for (var column = 0; column < line.length; column++) {
        final codePoint = line.getCodePoint(column);
        final width = line.getWidth(column);
        if (codePoint == 0) continue;
        text.writeCharCode(codePoint);
        positions.add(
          _SearchPosition(row: row, column: column, endColumn: column + width),
        );
      }
    }
    return _SearchBuffer(text: text.toString(), positions: positions);
  }

  void nextMatch() {
    if (_matches.isEmpty) return;
    _currentIndex = (currentIndex + 1) % _matches.length;
    _createHighlights();
  }

  void previousMatch() {
    if (_matches.isEmpty) return;
    _currentIndex = (currentIndex - 1 + _matches.length) % _matches.length;
    _createHighlights();
  }

  void _createHighlights() {
    _clearHighlights();
    for (var i = 0; i < _matches.length; i++) {
      final m = _matches[i];
      final isCurrent = i == _currentIndex;
      _highlights.add(
        terminalController.highlight(
          p1: terminal.buffer.createAnchor(m.start, m.startRow),
          p2: terminal.buffer.createAnchor(m.end, m.endRow),
          backgroundColor: isCurrent
              ? searchHitBackgroundCurrent
              : searchHitBackground,
        ),
      );
    }
  }

  void _clearHighlights() {
    for (final h in _highlights) {
      h.dispose();
    }
    _highlights.clear();
  }

  void dispose() {
    _clearHighlights();
    _matches.clear();
  }
}

class TerminalFindBar extends StatefulWidget {
  const TerminalFindBar({
    super.key,
    required this.session,
    required this.onClose,
    required this.onQueryChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onCaseSensitiveToggled,
    required this.onWholeWordToggled,
    required this.onUseRegexToggled,
    this.fontSize = 14,
  });

  final TerminalFindSession session;
  final VoidCallback onClose;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final ValueChanged<bool> onCaseSensitiveToggled;
  final ValueChanged<bool> onWholeWordToggled;
  final ValueChanged<bool> onUseRegexToggled;
  final double fontSize;

  @override
  State<TerminalFindBar> createState() => _TerminalFindBarState();
}

class _TerminalFindBarState extends State<TerminalFindBar> {
  final _inputFocusNode = FocusNode();
  final _inputController = TextEditingController();
  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _useRegex = false;

  @override
  void initState() {
    super.initState();
    _inputController.text = _displayQuery(widget.session.query);
    _inputController.addListener(() {
      widget.onQueryChanged(_searchQuery(_inputController.text));
    });
  }

  String _displayQuery(String query) {
    return query.replaceAll('\n', r'\n');
  }

  String _searchQuery(String query) {
    return query.replaceAll(r'\n', '\n');
  }

  @override
  void didUpdateWidget(TerminalFindBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _inputController.text = _displayQuery(widget.session.query);
    }
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final matchCount = session.matchCount;
    final currentIndex = session.currentIndex;
    final hasQuery = session.query.isNotEmpty;
    final countText = hasQuery && matchCount > 0
        ? '${currentIndex + 1} of $matchCount'
        : 'No results';

    const base = Color(0xFFBDC9D1);

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onClose();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              widget.onPrevious();
            } else {
              widget.onNext();
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.onNext();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.onPrevious();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: 420,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1D2124),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 230,
                  height: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF202529),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF404A4F)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 120,
                          height: 32,
                          child: TextField(
                            focusNode: _inputFocusNode,
                            controller: _inputController,
                            autofocus: true,
                            enableInteractiveSelection: true,
                            textAlignVertical: TextAlignVertical.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                              color: base,
                            ),
                            strutStyle: const StrutStyle(
                              fontSize: 14,
                              height: 1.0,
                              forceStrutHeight: true,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(
                                top: 12,
                                bottom: 6,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        _FigmaToggle(
                          label: 'Aa',
                          active: _caseSensitive,
                          onTap: () {
                            setState(() => _caseSensitive = !_caseSensitive);
                            widget.onCaseSensitiveToggled(_caseSensitive);
                            _inputFocusNode.requestFocus();
                          },
                        ),
                        const SizedBox(width: 2),
                        _FigmaToggle(
                          label: 'ab',
                          active: _wholeWord,
                          underline: true,
                          onTap: () {
                            setState(() => _wholeWord = !_wholeWord);
                            widget.onWholeWordToggled(_wholeWord);
                            _inputFocusNode.requestFocus();
                          },
                        ),
                        const SizedBox(width: 2),
                        _FigmaToggle(
                          label: '.*',
                          active: _useRegex,
                          onTap: () {
                            setState(() => _useRegex = !_useRegex);
                            widget.onUseRegexToggled(_useRegex);
                            _inputFocusNode.requestFocus();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 62,
                  height: 32,
                  child: Center(
                    child: Text(
                      countText,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: base,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _FigmaIconButton(
                  label: '↑',
                  fontSize: 20,
                  onTap: widget.onPrevious,
                ),
                const SizedBox(width: 2),
                _FigmaIconButton(
                  label: '↓',
                  fontSize: 20,
                  onTap: widget.onNext,
                ),
                const SizedBox(width: 2),
                _FigmaIconButton(
                  label: '×',
                  fontSize: 22,
                  onTap: widget.onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FigmaMenuButton extends StatefulWidget {
  const _FigmaMenuButton({required this.color});

  final Color color;

  @override
  State<_FigmaMenuButton> createState() => _FigmaMenuButtonState();
}

class _FigmaMenuButtonState extends State<_FigmaMenuButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        width: 32,
        height: 30,
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFF3A3D41) : const Color(0xFF2F363B),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (_) => Container(
              width: 14,
              height: 1.5,
              margin: const EdgeInsets.symmetric(vertical: 2.5),
              color: _hovered ? Colors.white : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _FigmaToggle extends StatefulWidget {
  const _FigmaToggle({
    required this.label,
    required this.active,
    this.onTap,
    this.underline = false,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final bool underline;

  @override
  State<_FigmaToggle> createState() => _FigmaToggleState();
}

class _FigmaToggleState extends State<_FigmaToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.active ? AppColors.accent : const Color(0xFFBDC9D1);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: _hovered
              ? BoxDecoration(
                  color: const Color(0xFF3A3D41),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: widget.label == 'Aa' ? 14 : 15,
              fontWeight: FontWeight.w500,
              height: 1.0,
              color: fg,
              decoration: widget.underline
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationColor: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _FigmaIconButton extends StatefulWidget {
  const _FigmaIconButton({
    required this.label,
    required this.fontSize,
    required this.onTap,
  });

  final String label;
  final double fontSize;
  final VoidCallback onTap;

  @override
  State<_FigmaIconButton> createState() => _FigmaIconButtonState();
}

class _FigmaIconButtonState extends State<_FigmaIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: _hovered
              ? BoxDecoration(
                  color: const Color(0xFF3A3D41),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: widget.fontSize,
              fontWeight: widget.label == '×'
                  ? FontWeight.w200
                  : FontWeight.w300,
              height: 1.0,
              color: const Color(0xFFBDC9D1),
            ),
          ),
        ),
      ),
    );
  }
}
