import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../../core/models/theme_settings.dart';
import '../../core/theme/app_colors.dart';
import '../ssh/ssh_bridge.dart';
import 'terminal_find.dart';
import 'terminal_state.dart';

class TerminalView extends StatefulWidget {
  const TerminalView({
    super.key,
    required this.tab,
    required this.sshBridge,
    required this.terminalThemeSettings,
    this.onSshInput,
    this.findVisible = false,
    this.findQuery = '',
    this.findCaseSensitive = false,
    this.findWholeWord = false,
    this.findUseRegex = false,
    this.onFindOpened,
    this.onFindClosed,
    this.onFindQueryChanged,
    this.onFindCaseSensitiveChanged,
    this.onFindWholeWordChanged,
    this.onFindUseRegexChanged,
  });

  final OpenTerminalTab tab;
  final SshBridgeClient sshBridge;
  final TerminalThemeSettings terminalThemeSettings;
  final ValueChanged<String>? onSshInput;
  final bool findVisible;
  final String findQuery;
  final bool findCaseSensitive;
  final bool findWholeWord;
  final bool findUseRegex;
  final ValueChanged<String>? onFindOpened;
  final VoidCallback? onFindClosed;
  final ValueChanged<String>? onFindQueryChanged;
  final ValueChanged<bool>? onFindCaseSensitiveChanged;
  final ValueChanged<bool>? onFindWholeWordChanged;
  final ValueChanged<bool>? onFindUseRegexChanged;

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  final inputFocusNode = FocusNode();
  final textController = TextEditingController();
  final terminalController = xterm.TerminalController();
  final regexHighlights = <xterm.TerminalHighlight>[];
  late final xterm.Terminal terminal;
  Timer? _resizeDebounce;
  Timer? _regexHighlightDebounce;
  Timer? _cursorIdleTimer;
  Timer? _cursorBlinkTimer;
  bool _cursorVisible = true;
  final _findScrollController = ScrollController();
  TerminalFindSession? _findSession;
  bool _localFindVisible = false;
  @override
  void initState() {
    super.initState();
    terminal =
        widget.tab.terminal ??
        xterm.Terminal(maxLines: widget.terminalThemeSettings.scrollbackLines);
    _applyCursorBlinkMode();
    terminal.addListener(_handleTerminalChanged);
    textController.addListener(_handleTextEditingChanged);
    _refreshRegexHighlights();

    if (widget.tab.sourceType == TerminalSourceType.ssh) {
      if (widget.tab.terminal == null && widget.tab.history.isNotEmpty) {
        terminal.write(widget.tab.history);
      }
      final sessionId = widget.tab.sessionId;
      if (sessionId != null) {
        _bindSshSession(sessionId);
      }
    } else {
      terminal.write('Connected to ${widget.tab.welcomeTarget}\r\n');
      terminal.write('DeepSSH UI prototype terminal\r\n');
      terminal.write('\r\n');
      terminal.write(r'$ echo hello from xterm.dart\r\n');
      terminal.write('hello from xterm.dart\r\n');
    }
    _syncFindSession();
  }

  void _bindSshSession(String sessionId) {
    terminal.onResize = (width, height, _, _) {
      _syncSshSize(sessionId, width, height);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.tab.sessionId == sessionId) {
        _syncSshSize(sessionId, terminal.viewWidth, terminal.viewHeight);
      }
    });
    terminal.onOutput = (data) {
      widget.onSshInput?.call(data);
      widget.sshBridge.writeToSession(sessionId, utf8.encode(data));
    };
  }

  void _syncSshSize(String sessionId, int width, int height) {
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 80), () {
      widget.sshBridge.resizeSession(
        sessionId: sessionId,
        rows: height,
        cols: width,
      );
    });
  }

  void _handleTerminalChanged() {
    _resetCursorBlinkIdle();
    _scheduleRegexHighlightsRefresh();
  }

  void _scheduleRegexHighlightsRefresh() {
    _regexHighlightDebounce?.cancel();
    _regexHighlightDebounce = Timer(const Duration(milliseconds: 80), () {
      if (mounted) {
        _refreshRegexHighlights();
      }
    });
  }

  void _refreshRegexHighlights() {
    for (final highlight in regexHighlights) {
      highlight.dispose();
    }
    regexHighlights.clear();

    for (final rule in widget.terminalThemeSettings.regexHighlights) {
      if (rule.pattern.isEmpty) continue;
      final regex = _compileRegex(rule.pattern);
      if (regex == null) continue;

      final lines = terminal.buffer.lines;
      for (var row = 0; row < lines.length; row++) {
        final lineText = lines[row].getText();
        for (final match in regex.allMatches(lineText)) {
          if (match.start == match.end) continue;
          regexHighlights.add(
            terminalController.highlight(
              p1: terminal.buffer.createAnchor(match.start, row),
              p2: terminal.buffer.createAnchor(match.end, row),
              foregroundColor: rule.color,
            ),
          );
        }
      }
    }
  }

  RegExp? _compileRegex(String pattern) {
    try {
      return RegExp(pattern);
    } on FormatException {
      return null;
    }
  }

  void _applyCursorBlinkMode() {
    terminal.setCursorBlinkMode(widget.terminalThemeSettings.cursorBlink);
    _resetCursorBlinkIdle();
  }

  void _setCursorBlinkVisible(bool visible) {
    if (_cursorVisible == visible) return;
    setState(() {
      _cursorVisible = visible;
    });
  }

  void _resetCursorBlinkIdle() {
    _cursorIdleTimer?.cancel();
    _cursorBlinkTimer?.cancel();
    _setCursorBlinkVisible(true);
    if (!widget.terminalThemeSettings.cursorBlink) return;

    _cursorIdleTimer = Timer(const Duration(milliseconds: 500), () {
      _setCursorBlinkVisible(false);
      _cursorBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (
        _,
      ) {
        _setCursorBlinkVisible(!_cursorVisible);
      });
    });
  }

  Color _terminalSelectionColor(TerminalThemeSettings settings) {
    return settings.selectionColor.withValues(alpha: 0.45);
  }

  void _handleTextEditingChanged() {
    final value = textController.value;
    if (value.text.isEmpty) return;
    if (value.composing.isValid && !value.composing.isCollapsed) {
      return;
    }
    _resetCursorBlinkIdle();
    terminal.textInput(value.text);
    textController.clear();
  }

  KeyEventResult _handleTerminalKeyEvent(FocusNode focusNode, KeyEvent event) {
    if (event is KeyDownEvent &&
        HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.keyC &&
        _copySelectionIfNotEmpty()) {
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.keyF) {
      if (_effectiveFindVisible) {
        _closeFind();
      } else {
        _openFind();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleProxyKeyEvent(FocusNode focusNode, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    if (HardwareKeyboard.instance.isControlPressed) {
      final character = event.character;
      if (character != null && character.isNotEmpty) {
        final codeUnit = character.toLowerCase().codeUnitAt(0);
        if (codeUnit >= 97 && codeUnit <= 122) {
          final controlText = String.fromCharCode(codeUnit - 96);
          _resetCursorBlinkIdle();
          terminal.textInput(controlText);
          return KeyEventResult.handled;
        }
      }
      final keyLabel = event.logicalKey.keyLabel;
      if (keyLabel.length == 1) {
        final codeUnit = keyLabel.toLowerCase().codeUnitAt(0);
        if (codeUnit >= 97 && codeUnit <= 122) {
          final controlText = String.fromCharCode(codeUnit - 96);
          _resetCursorBlinkIdle();
          terminal.textInput(controlText);
          return KeyEventResult.handled;
        }
      }
    }

    final key = switch (event.logicalKey) {
      LogicalKeyboardKey.enter => xterm.TerminalKey.enter,
      LogicalKeyboardKey.backspace => xterm.TerminalKey.backspace,
      LogicalKeyboardKey.delete => xterm.TerminalKey.delete,
      LogicalKeyboardKey.arrowUp => xterm.TerminalKey.arrowUp,
      LogicalKeyboardKey.arrowDown => xterm.TerminalKey.arrowDown,
      LogicalKeyboardKey.arrowLeft => xterm.TerminalKey.arrowLeft,
      LogicalKeyboardKey.arrowRight => xterm.TerminalKey.arrowRight,
      LogicalKeyboardKey.home => xterm.TerminalKey.home,
      LogicalKeyboardKey.end => xterm.TerminalKey.end,
      LogicalKeyboardKey.pageUp => xterm.TerminalKey.pageUp,
      LogicalKeyboardKey.pageDown => xterm.TerminalKey.pageDown,
      LogicalKeyboardKey.tab => xterm.TerminalKey.tab,
      LogicalKeyboardKey.escape => xterm.TerminalKey.escape,
      _ => null,
    };
    if (key == null) {
      return KeyEventResult.ignored;
    }

    final handled = terminal.keyInput(
      key,
      ctrl: HardwareKeyboard.instance.isControlPressed,
      alt: HardwareKeyboard.instance.isAltPressed,
      shift: HardwareKeyboard.instance.isShiftPressed,
    );
    if (handled) {
      _resetCursorBlinkIdle();
    }
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  static const Color _menuAccent = Color(0xFFFFB280);
  static const double _menuItemHeight = 32;
  static const double _menuWidth = 120;

  void _showContextMenu(BuildContext context, Offset position) {
    final selection = terminalController.selection;
    final hasSelection =
        selection != null && terminal.buffer.getText(selection).isNotEmpty;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final relativePosition = RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: relativePosition,
      color: AppColors.panel,
      elevation: 8,
      shadowColor: const Color(0x66000000),
      surfaceTintColor: Colors.transparent,
      menuPadding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: _menuWidth),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: AppColors.border),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          enabled: hasSelection,
          height: _menuItemHeight,
          padding: EdgeInsets.zero,
          child: _TerminalContextMenuItem(label: '复制', enabled: hasSelection),
        ),
        const PopupMenuItem<String>(
          value: 'paste',
          height: _menuItemHeight,
          padding: EdgeInsets.zero,
          child: _TerminalContextMenuItem(label: '粘贴'),
        ),
      ],
    ).then((value) {
      if (!mounted) return;
      if (value == 'copy') {
        _copySelection();
        _focusInputProxy();
      } else if (value == 'paste') {
        _pasteFromClipboard();
      } else {
        _focusInputProxy();
      }
    });
  }

  bool _copySelectionIfNotEmpty() {
    final selection = terminalController.selection;
    if (selection == null) return false;
    final text = terminal.buffer.getText(selection);
    if (text.isEmpty) return false;
    Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  void _copySelection() {
    _copySelectionIfNotEmpty();
  }

  void _pasteFromClipboard() {
    Clipboard.getData(Clipboard.kTextPlain).then((data) {
      if (!mounted) return;
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        terminal.textInput(data.text!);
      }
      _focusInputProxy();
    });
  }

  void _focusInputProxy() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !inputFocusNode.hasFocus) {
        inputFocusNode.requestFocus();
      }
    });
  }

  void _openFind() {
    final selection = terminalController.selection;
    final selectedText = selection == null
        ? ''
        : terminal.buffer.getText(selection);
    final hasGlobalFindOwner = widget.onFindOpened != null;
    if (hasGlobalFindOwner) {
      widget.onFindOpened!(selectedText);
    } else {
      _localFindVisible = true;
      _ensureFindSession(query: selectedText.isNotEmpty ? selectedText : null);
      setState(() {});
    }
  }

  void _closeFind() {
    widget.onFindClosed?.call();
    _localFindVisible = false;
    _findSession?.dispose();
    _findSession = null;
    if (widget.onFindClosed == null) {
      setState(() {});
    }
    _focusInputProxy();
  }

  bool get _effectiveFindVisible => widget.findVisible || _localFindVisible;

  String get _effectiveFindQuery =>
      widget.findVisible ? widget.findQuery : _findSession?.query ?? '';

  bool get _effectiveFindCaseSensitive => widget.findVisible
      ? widget.findCaseSensitive
      : _findSession?.caseSensitive ?? false;

  bool get _effectiveFindWholeWord => widget.findVisible
      ? widget.findWholeWord
      : _findSession?.wholeWord ?? false;

  bool get _effectiveFindUseRegex => widget.findVisible
      ? widget.findUseRegex
      : _findSession?.useRegex ?? false;

  void _ensureFindSession({String? query}) {
    _findSession ??= TerminalFindSession(
      terminal: terminal,
      terminalController: terminalController,
      searchHitBackground: const Color(0xFF264F78),
      searchHitBackgroundCurrent: const Color(0xFF515C6A),
    );
    _findSession!.setCaseSensitive(_effectiveFindCaseSensitive);
    _findSession!.setWholeWord(_effectiveFindWholeWord);
    _findSession!.setUseRegex(_effectiveFindUseRegex);
    _findSession!.setQuery(query ?? _effectiveFindQuery);
  }

  void _syncFindSession() {
    if (!_effectiveFindVisible) {
      _findSession?.dispose();
      _findSession = null;
      return;
    }
    _ensureFindSession();
  }

  void _scrollToCurrentMatch() {
    final session = _findSession;
    if (session == null || !_findScrollController.hasClients) return;
    final matchRow = session.currentMatchRow;
    if (matchRow == null) return;

    final position = _findScrollController.position;
    final lineCount = terminal.buffer.lines.length;
    if (lineCount == 0) return;

    final lineHeight =
        (position.maxScrollExtent + position.viewportDimension) / lineCount;
    final targetOffset =
        (matchRow * lineHeight) -
        ((position.viewportDimension - lineHeight) / 2);
    final scrollOffset = targetOffset.clamp(0.0, position.maxScrollExtent);

    _findScrollController.animateTo(
      scrollOffset,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSessionId = oldWidget.tab.sessionId;
    final sessionId = widget.tab.sessionId;
    if (oldWidget.terminalThemeSettings.cursorBlink !=
        widget.terminalThemeSettings.cursorBlink) {
      _applyCursorBlinkMode();
    }
    if (oldWidget.terminalThemeSettings.regexHighlights !=
        widget.terminalThemeSettings.regexHighlights) {
      _regexHighlightDebounce?.cancel();
      _refreshRegexHighlights();
    }
    if (oldSessionId != sessionId && sessionId != null) {
      _bindSshSession(sessionId);
    }
    final findChanged =
        oldWidget.findVisible != widget.findVisible ||
        oldWidget.findQuery != widget.findQuery ||
        oldWidget.findCaseSensitive != widget.findCaseSensitive ||
        oldWidget.findWholeWord != widget.findWholeWord ||
        oldWidget.findUseRegex != widget.findUseRegex;
    _syncFindSession();
    if (findChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrentMatch();
      });
    }
    if (widget.tab.terminal == null &&
        widget.tab.history.startsWith(oldWidget.tab.history)) {
      final nextText = widget.tab.history.substring(
        oldWidget.tab.history.length,
      );
      if (nextText.isNotEmpty) {
        terminal.write(nextText);
      }
    }
  }

  @override
  void dispose() {
    _resizeDebounce?.cancel();
    _regexHighlightDebounce?.cancel();
    _cursorIdleTimer?.cancel();
    _cursorBlinkTimer?.cancel();
    for (final highlight in regexHighlights) {
      highlight.dispose();
    }
    regexHighlights.clear();
    _findSession?.dispose();
    _findScrollController.dispose();
    terminalController.dispose();
    terminal.removeListener(_handleTerminalChanged);
    inputFocusNode.dispose();
    textController.dispose();
    super.dispose();
  }

  xterm.TerminalCursorType _xtermCursorType(CursorStyle style) {
    switch (style) {
      case CursorStyle.block:
        return xterm.TerminalCursorType.block;
      case CursorStyle.underline:
        return xterm.TerminalCursorType.underline;
      case CursorStyle.bar:
        return xterm.TerminalCursorType.verticalBar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.terminalThemeSettings;
    return Container(
      color: AppColors.panel,
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                if (event.buttons == kSecondaryButton) {
                  _showContextMenu(context, event.position);
                } else {
                  _focusInputProxy();
                }
              },
              child: xterm.TerminalView(
                terminal,
                controller: terminalController,
                scrollController: _findScrollController,
                focusNode: inputFocusNode,
                hardwareKeyboardOnly: true,
                onKeyEvent: _handleTerminalKeyEvent,
                cursorType: _xtermCursorType(settings.cursorStyle),
                alwaysShowCursor: false,
                cursorBlinkVisible: _cursorVisible,
                textStyle: xterm.TerminalStyle(
                  fontSize: settings.fontSize.toDouble(),
                  fontFamily: settings.fontFamily,
                ),
                theme: xterm.TerminalTheme(
                  cursor: settings.cursorColor,
                  selection: _terminalSelectionColor(settings),
                  foreground: settings.foreground,
                  background: settings.terminalBackground,
                  black: const Color(0xFF000000),
                  red: const Color(0xFFCD3131),
                  green: const Color(0xFF0DBC79),
                  yellow: const Color(0xFFE5E510),
                  blue: const Color(0xFF2472C8),
                  magenta: const Color(0xFFBC3FBC),
                  cyan: const Color(0xFF11A8CD),
                  white: const Color(0xFFE5E5E5),
                  brightBlack: const Color(0xFF666666),
                  brightRed: const Color(0xFFF14C4C),
                  brightGreen: const Color(0xFF23D18B),
                  brightYellow: const Color(0xFFF5F543),
                  brightBlue: const Color(0xFF3B8EEA),
                  brightMagenta: const Color(0xFFD670D6),
                  brightCyan: const Color(0xFF29B8DB),
                  brightWhite: const Color(0xFFE5E5E5),
                  searchHitBackground: const Color(0xFF264F78),
                  searchHitBackgroundCurrent: const Color(0xFF515C6A),
                  searchHitForeground: settings.foreground,
                ),
              ),
            ),
          ),
          Positioned(
            width: 1,
            height: 1,
            child: Opacity(
              opacity: 0.01,
              child: Focus(
                onKeyEvent: _handleProxyKeyEvent,
                child: TextField(
                  key: const Key('terminal-input-proxy'),
                  focusNode: inputFocusNode,
                  controller: textController,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.none,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(color: Colors.transparent),
                  cursorColor: Colors.transparent,
                ),
              ),
            ),
          ),
          if (_effectiveFindVisible && _findSession != null)
            Positioned(
              top: 0,
              right: 0,
              child: TerminalFindBar(
                session: _findSession!,
                fontSize: widget.terminalThemeSettings.fontSize.toDouble(),
                onClose: _closeFind,
                onQueryChanged: (query) {
                  widget.onFindQueryChanged?.call(query);
                  _findSession!.setQuery(query);
                  _scrollToCurrentMatch();
                },
                onNext: () {
                  _findSession!.nextMatch();
                  _scrollToCurrentMatch();
                },
                onPrevious: () {
                  _findSession!.previousMatch();
                  _scrollToCurrentMatch();
                },
                onCaseSensitiveToggled: (value) {
                  widget.onFindCaseSensitiveChanged?.call(value);
                  _findSession!.setCaseSensitive(value);
                },
                onWholeWordToggled: (value) {
                  widget.onFindWholeWordChanged?.call(value);
                  _findSession!.setWholeWord(value);
                },
                onUseRegexToggled: (value) {
                  widget.onFindUseRegexChanged?.call(value);
                  _findSession!.setUseRegex(value);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TerminalContextMenuItem extends StatefulWidget {
  const _TerminalContextMenuItem({required this.label, this.enabled = true});

  final String label;
  final bool enabled;

  @override
  State<_TerminalContextMenuItem> createState() =>
      _TerminalContextMenuItemState();
}

class _TerminalContextMenuItemState extends State<_TerminalContextMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.enabled && _hovered;
    final foreground = widget.enabled
        ? AppColors.textPrimary
        : AppColors.textMuted.withValues(alpha: 0.45);

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: widget.enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _hovered = false) : null,
      child: Container(
        width: _TerminalViewState._menuWidth,
        height: _TerminalViewState._menuItemHeight,
        color: highlighted ? AppColors.tabHover : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 3,
              height: double.infinity,
              color: highlighted
                  ? _TerminalViewState._menuAccent
                  : Colors.transparent,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
