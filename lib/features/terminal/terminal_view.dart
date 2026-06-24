import 'dart:async';
import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../../core/models/theme_settings.dart';
import '../../core/theme/app_colors.dart';
import '../local_terminal/local_terminal_bridge.dart';
import '../ssh/ssh_bridge.dart';
import 'terminal_find.dart';
import 'terminal_state.dart';

typedef SshTerminalInputWriter = void Function(String sessionId, String data);

class TerminalView extends StatefulWidget {
  const TerminalView({
    super.key,
    required this.tab,
    required this.sshBridge,
    required this.localTerminalBridge,
    required this.terminalThemeSettings,
    this.onSshInput,
    this.onSshTerminalInput,
    this.onLocalInput,
    this.onPreviewLabelChanged,
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
  final LocalTerminalBridgeClient localTerminalBridge;
  final TerminalThemeSettings terminalThemeSettings;
  final ValueChanged<String>? onSshInput;
  final SshTerminalInputWriter? onSshTerminalInput;
  final ValueChanged<String>? onLocalInput;
  final ValueChanged<String>? onPreviewLabelChanged;
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
  final _xtermTerminalViewKey = GlobalKey<xterm.TerminalViewState>();
  final _terminalStackKey = GlobalKey();
  TextEditingController? _textController;
  final terminalController = xterm.TerminalController();
  late final xterm.Terminal terminal;
  late List<_CompiledRegexHighlight> _compiledRegexHighlights;
  Timer? _resizeDebounce;
  Timer? _cursorIdleTimer;
  Timer? _cursorBlinkTimer;
  bool _cursorVisible = true;
  String _lastPreviewLabel = '';
  final _findScrollController = ScrollController();
  TerminalFindSession? _findSession;
  bool _localFindVisible = false;
  Offset _proxyInputOffset = Offset.zero;
  bool _proxyInputOffsetUpdateScheduled = false;

  bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  // When Windows pastes multi-line text, it fires an Enter key event for the
  // \n after injecting the first line into the proxy TextField. We suppress
  // that Enter so the pasted line is not immediately executed.
  bool _suppressNextEnter = false;

  // Tracks whether the proxy TextField was in IME composition on the previous
  // change. Used to distinguish a paste (length > 1, not composing) from an
  // IME commit (length > 1, but was composing).
  bool _wasComposing = false;

  @override
  void initState() {
    super.initState();
    terminal =
        widget.tab.terminal ??
        xterm.Terminal(maxLines: widget.terminalThemeSettings.scrollbackLines);
    _compiledRegexHighlights = _compileRegexHighlightRules();
    _applyCursorBlinkMode();
    terminal.addListener(_handleTerminalChanged);
    if (!_isMacOS) {
      _textController = TextEditingController();
      _textController!.addListener(_handleTextEditingChanged);
    }

    if (widget.tab.sourceType == TerminalSourceType.ssh) {
      if (widget.tab.terminal == null && widget.tab.history.isNotEmpty) {
        terminal.write(widget.tab.history);
      }
      final sessionId = widget.tab.sessionId;
      if (sessionId != null) {
        _bindSshSession(sessionId);
      }
    } else if (widget.tab.sourceType == TerminalSourceType.local) {
      final sessionId = widget.tab.sessionId;
      if (sessionId != null) {
        _bindLocalSession(sessionId);
      }
    } else {
      terminal.write('Connected to ${widget.tab.welcomeTarget}\r\n');
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
      _resetCursorBlinkIdle();
      widget.onSshInput?.call(data);
      final inputWriter = widget.onSshTerminalInput;
      if (inputWriter != null) {
        inputWriter(sessionId, data);
      } else {
        widget.sshBridge.writeToSession(sessionId, utf8.encode(data));
      }
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

  void _bindLocalSession(String sessionId) {
    terminal.onResize = (width, height, _, _) {
      _syncLocalSize(sessionId, width, height);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.tab.sessionId == sessionId) {
        _syncLocalSize(sessionId, terminal.viewWidth, terminal.viewHeight);
      }
    });
    terminal.onOutput = (data) {
      _resetCursorBlinkIdle();
      widget.onLocalInput?.call(data);
      widget.localTerminalBridge.writeToSession(sessionId, utf8.encode(data));
    };
  }

  void _syncLocalSize(String sessionId, int width, int height) {
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 80), () {
      widget.localTerminalBridge.resizeSession(
        sessionId: sessionId,
        rows: height,
        cols: width,
      );
    });
  }

  // Debounce timer for preview label extraction — avoids running the
  // characters.take() Unicode scan on every single keystroke.
  Timer? _previewLabelDebounce;

  void _handleTerminalChanged() {
    _resetCursorBlinkIdle();
    _scheduleProxyInputOffsetUpdate();
    _schedulePreviewLabelEmit();
  }

  void _schedulePreviewLabelEmit() {
    _previewLabelDebounce?.cancel();
    _previewLabelDebounce = Timer(const Duration(milliseconds: 80), () {
      if (mounted) _emitPreviewLabelIfNeeded();
    });
  }

  String _extractPreviewLabel() {
    final text = terminal.buffer.currentLine.getText().trim();
    if (text.isEmpty) return '';
    return text.characters.take(100).toString();
  }

  void _emitPreviewLabelIfNeeded() {
    final preview = _extractPreviewLabel();
    if (preview.isEmpty || preview == _lastPreviewLabel) {
      return;
    }
    _lastPreviewLabel = preview;
    widget.onPreviewLabelChanged?.call(preview);
  }

  List<_CompiledRegexHighlight> _compileRegexHighlightRules() {
    final rules = <_CompiledRegexHighlight>[];
    for (final rule in widget.terminalThemeSettings.regexHighlights) {
      if (rule.pattern.isEmpty) continue;
      try {
        rules.add(
          _CompiledRegexHighlight(
            regex: RegExp(rule.pattern),
            foreground: rule.color,
          ),
        );
      } on FormatException {
        continue;
      }
    }
    return rules;
  }

  void _regexForegroundForRow(
    int row,
    String lineText,
    List<Color?> foregroundColors,
    int rowOffset,
    int viewWidth,
  ) {
    final line = terminal.buffer.lines[row];
    final end = line.length < viewWidth ? line.length : viewWidth;
    for (final rule in _compiledRegexHighlights.reversed) {
      _applyRegexForegroundRule(
        line: line,
        regex: rule.regex,
        lineText: lineText,
        foreground: rule.foreground,
        foregroundColors: foregroundColors,
        rowOffset: rowOffset,
        end: end,
      );
    }
  }

  void _applyRegexForegroundRule({
    required xterm.BufferLine line,
    required RegExp regex,
    required String lineText,
    required Color foreground,
    required List<Color?> foregroundColors,
    required int rowOffset,
    required int end,
  }) {
    final matches = regex.allMatches(lineText).iterator;
    if (!matches.moveNext()) return;
    var match = matches.current;
    var textIndex = 0;

    for (var cell = 0; cell < end; cell++) {
      final codePoint = line.getCodePoint(cell);
      if (codePoint == 0) {
        if (cell == 0 || line.getWidth(cell - 1) != 2) {
          textIndex++;
        }
        continue;
      }

      final start = textIndex;
      final width = line.getWidth(cell);
      textIndex += String.fromCharCode(codePoint).length;

      while (match.start == match.end || start >= match.end) {
        if (!matches.moveNext()) return;
        match = matches.current;
      }

      final inMatch = start >= match.start && start < match.end;
      if (inMatch) {
        foregroundColors[rowOffset + cell] = foreground;
        if (width == 2 && cell + 1 < end) {
          foregroundColors[rowOffset + cell + 1] = foreground;
        }
      }
      if (width == 2 && cell + 1 < end) {
        cell++;
      }
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

  void _handleTextEditingChanged() {
    final value = _textController!.value;
    if (value.text.isEmpty) {
      _wasComposing = false;
      return;
    }
    if (value.composing.isValid && !value.composing.isCollapsed) {
      _wasComposing = true;
      return;
    }
    _resetCursorBlinkIdle();
    // Distinguish paste from IME commit:
    // - IME commit: _wasComposing was true before this change, so even if
    //   multiple chars are committed (e.g. "你好"), we send them as normal input.
    // - Paste: length > 1 with no prior composition means the platform injected
    //   clipboard text. Discard it, read the full clipboard ourselves, and use
    //   terminal.paste() so bracketed paste mode is respected. Also arm
    //   _suppressNextEnter for the \n Windows fires after the first line.
    if (value.text.length > 1 && !_wasComposing) {
      _suppressNextEnter = true;
      _wasComposing = false;
      _textController!.clear();
      _pasteFromClipboard();
      return;
    }
    _wasComposing = false;
    terminal.textInput(value.text);
    _textController!.clear();
  }

  KeyEventResult _handleProxyKeyEvent(FocusNode focusNode, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    // Suppress the Enter key event that Windows fires for the \n in pasted
    // multi-line text. _handleTextEditingChanged arms this flag when it detects
    // a paste (text length > 1 with no IME composition).
    if (_suppressNextEnter &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter) {
      _suppressNextEnter = false;
      return KeyEventResult.handled;
    }

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
        _focusTerminalInput();
      } else if (value == 'paste') {
        _pasteFromClipboard();
      } else {
        _focusTerminalInput();
      }
    });
  }

  bool _copySelectionIfNotEmpty() {
    final selection = terminalController.selection;
    if (selection == null) return false;
    final text = terminal.buffer.getText(selection);
    if (text.isEmpty) return false;
    // buffer.getText() already clamps each line to its last cell with content
    // (getTrimmedLength): trailing *empty* cells (never written, codePoint == 0)
    // are dropped, while written spaces (codePoint == 0x20) are preserved
    // verbatim. So the copied text hugs the actual terminal content.
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
        // Normalize line endings: Windows/VSCode clipboard uses \r\n (CRLF),
        // which causes each line break to appear as two newlines in the
        // terminal. Convert \r\n → \n, then lone \r → \n for safety.
        final text = data.text!.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        // Use paste() instead of textInput() so that bracketed paste mode is
        // respected. Modern shells (bash, zsh, fish) use bracketed paste to
        // prevent multi-line text from being executed immediately.
        terminal.paste(text);
      }
      _focusTerminalInput();
    });
  }

  void _focusTerminalInput() {
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
    _focusTerminalInput();
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
      searchHitBackground: AppColors.accent.withOpacity(0.3),
      searchHitBackgroundCurrent: AppColors.accent.withOpacity(0.7),
    );
    _findSession!.setCaseSensitive(_effectiveFindCaseSensitive);
    _findSession!.setWholeWord(_effectiveFindWholeWord);
    _findSession!.setUseRegex(_effectiveFindUseRegex);
    final newQuery = query ?? _effectiveFindQuery;
    if (_findSession!.query != newQuery) {
      _findSession!.setQuery(newQuery);
    }
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
      _compiledRegexHighlights = _compileRegexHighlightRules();
    }
    if (oldSessionId != sessionId && sessionId != null) {
      if (widget.tab.sourceType == TerminalSourceType.ssh) {
        _bindSshSession(sessionId);
      } else if (widget.tab.sourceType == TerminalSourceType.local) {
        _bindLocalSession(sessionId);
      }
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
    _cursorIdleTimer?.cancel();
    _cursorBlinkTimer?.cancel();
    _previewLabelDebounce?.cancel();
    _findSession?.dispose();
    _findScrollController.dispose();
    terminalController.dispose();
    terminal.removeListener(_handleTerminalChanged);
    inputFocusNode.dispose();
    _textController?.dispose();
    super.dispose();
  }

  void _scheduleProxyInputOffsetUpdate() {
    if (_isMacOS || _proxyInputOffsetUpdateScheduled) return;
    _proxyInputOffsetUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _proxyInputOffsetUpdateScheduled = false;
      if (!mounted) return;

      final terminalState = _xtermTerminalViewKey.currentState;
      final stackBox = _terminalStackKey.currentContext?.findRenderObject();
      if (terminalState == null ||
          stackBox is! RenderBox ||
          !stackBox.hasSize) {
        return;
      }

      final nextOffset = stackBox.globalToLocal(
        terminalState.globalCursorRect.topLeft,
      );
      if (nextOffset == _proxyInputOffset) return;
      setState(() {
        _proxyInputOffset = nextOffset;
      });
    });
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

  FontWeight _fontWeightFromConfig(int value) {
    return FontWeight.values.firstWhere(
      (weight) => weight.value == value,
      orElse: () => FontWeight.normal,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Do NOT call _scheduleProxyInputOffsetUpdate() here — it is already
    // triggered by _handleTerminalChanged() on every terminal update.
    // Calling it in build() creates a rebuild loop: terminal change →
    // setState (offset) → rebuild → scheduleUpdate → setState → rebuild…
    final settings = widget.terminalThemeSettings;
    return Container(
      color: AppColors.panel,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 17),
      child: Stack(
        key: _terminalStackKey,
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                if (event.buttons == kSecondaryButton) {
                  _showContextMenu(context, event.position);
                } else {
                  _focusTerminalInput();
                }
              },
              child: Scrollbar(
                controller: _findScrollController,
                child: xterm.TerminalView(
                  terminal,
                  key: _xtermTerminalViewKey,
                  controller: terminalController,
                  scrollController: _findScrollController,
                  focusNode: inputFocusNode,
                  autofocus: _isMacOS,
                  hardwareKeyboardOnly: !_isMacOS,
                  onKeyEvent: _handleTerminalKeyEvent,
                // macOS Cmd+C flows through xterm's TerminalActions -> onCopy.
                // `text` is already buffer.getText(), which clamps each line to
                // its last content cell: trailing empty cells are dropped and
                // written spaces are preserved. Same semantics as the Ctrl+C /
                // context-menu path above, on all platforms.
                onCopy: (text) {
                  if (text.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: text));
                  }
                },
                cursorType: _xtermCursorType(settings.cursorStyle),
                alwaysShowCursor: false,
                cursorBlinkVisible: _cursorVisible,
                foregroundColorResolver: _compiledRegexHighlights.isEmpty
                    ? null
                    : _regexForegroundForRow,
                textStyle: xterm.TerminalStyle(
                  fontSize: settings.fontSize.toDouble(),
                  fontFamily: settings.fontFamily,
                  normalFontWeight: _fontWeightFromConfig(
                    settings.normalFontWeight,
                  ),
                  boldFontWeight: _fontWeightFromConfig(
                    settings.boldFontWeight,
                  ),
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
                  searchHitBackground: AppColors.accent.withOpacity(0.3),
                  searchHitBackgroundCurrent: AppColors.accent.withOpacity(0.7),
                  searchHitForeground: settings.foreground,
                ),
                ),
              ),
            ),
          ),
          if (!_isMacOS)
            Positioned(
              left: _proxyInputOffset.dx,
              top: _proxyInputOffset.dy,
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0.01,
                child: Focus(
                  onKeyEvent: _handleProxyKeyEvent,
                  child: TextField(
                    key: const Key('terminal-input-proxy'),
                    focusNode: inputFocusNode,
                    controller: _textController,
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

class _CompiledRegexHighlight {
  const _CompiledRegexHighlight({
    required this.regex,
    required this.foreground,
  });

  final RegExp regex;
  final Color foreground;
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
