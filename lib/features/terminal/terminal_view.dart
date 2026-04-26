import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../../core/models/theme_settings.dart';
import '../../core/theme/app_colors.dart';
import '../ssh/ssh_bridge.dart';
import 'terminal_state.dart';

class TerminalView extends StatefulWidget {
  const TerminalView({
    super.key,
    required this.tab,
    required this.sshBridge,
    required this.terminalThemeSettings,
  });

  final OpenTerminalTab tab;
  final SshBridgeClient sshBridge;
  final TerminalThemeSettings terminalThemeSettings;

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  final inputFocusNode = FocusNode();
  final textController = TextEditingController();
  late final xterm.Terminal terminal;
  Timer? _resizeDebounce;
  Timer? _cursorIdleTimer;
  Timer? _cursorBlinkTimer;
  bool _cursorVisible = true;
  @override
  void initState() {
    super.initState();
    terminal = widget.tab.terminal ??
        xterm.Terminal(maxLines: widget.terminalThemeSettings.scrollbackLines);
    _applyCursorBlinkMode();
    terminal.addListener(_handleTerminalChanged);
    textController.addListener(_handleTextEditingChanged);

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
  }

  void logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  void _bindSshSession(String sessionId) {
    logDebug('[terminal:bind] session=$sessionId tab=${widget.tab.id}');
    terminal.onResize = (width, height, _, _) {
      _syncSshSize(sessionId, width, height);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.tab.sessionId == sessionId) {
        _syncSshSize(sessionId, terminal.viewWidth, terminal.viewHeight);
      }
    });
    terminal.onOutput = (data) {
      logDebug(
        '[terminal:onOutput] session=$sessionId data=${jsonEncode(data)}',
      );
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
      _cursorBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _setCursorBlinkVisible(!_cursorVisible);
      });
    });
  }

  Color _terminalSelectionColor(TerminalThemeSettings settings) {
    return settings.selectionColor.withValues(alpha: 0.45);
  }

  void _handleTextEditingChanged() {
    final value = textController.value;
    logDebug(
      '[terminal:edit] text=${jsonEncode(value.text)} '
      'selection=${value.selection.start}-${value.selection.end} '
      'composing=${value.composing.start}-${value.composing.end} '
      'valid=${value.composing.isValid} collapsed=${value.composing.isCollapsed}',
    );
    if (value.text.isEmpty) return;
    if (value.composing.isValid && !value.composing.isCollapsed) {
      logDebug('[terminal:edit] skip composing text=${jsonEncode(value.text)}');
      return;
    }
    logDebug('[terminal:edit] commit text=${jsonEncode(value.text)}');
    _resetCursorBlinkIdle();
    terminal.textInput(value.text);
    textController.clear();
  }

  KeyEventResult _handleProxyKeyEvent(FocusNode focusNode, KeyEvent event) {
    logDebug(
      '[terminal:key] focus=${focusNode.hasFocus} '
      'primary=${FocusManager.instance.primaryFocus?.debugLabel} '
      'type=${event.runtimeType} logical=${event.logicalKey.keyLabel} '
      'character=${jsonEncode(event.character)} '
      'ctrl=${HardwareKeyboard.instance.isControlPressed} '
      'alt=${HardwareKeyboard.instance.isAltPressed} '
      'shift=${HardwareKeyboard.instance.isShiftPressed} '
      'meta=${HardwareKeyboard.instance.isMetaPressed}',
    );
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    if (HardwareKeyboard.instance.isControlPressed) {
      final character = event.character;
      if (character != null && character.isNotEmpty) {
        final codeUnit = character.toLowerCase().codeUnitAt(0);
        if (codeUnit >= 97 && codeUnit <= 122) {
          final controlText = String.fromCharCode(codeUnit - 96);
          logDebug(
            '[terminal:key] ctrl-letter commit=${jsonEncode(controlText)}',
          );
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
          logDebug(
            '[terminal:key] ctrl-letter commit=${jsonEncode(controlText)}',
          );
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
      logDebug('[terminal:key] ignored unmapped');
      return KeyEventResult.ignored;
    }

    final handled = terminal.keyInput(
      key,
      ctrl: HardwareKeyboard.instance.isControlPressed,
      alt: HardwareKeyboard.instance.isAltPressed,
      shift: HardwareKeyboard.instance.isShiftPressed,
    );
    logDebug('[terminal:key] keyInput key=$key handled=$handled');
    if (handled) {
      _resetCursorBlinkIdle();
    }
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _focusInputProxy() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !inputFocusNode.hasFocus) {
        inputFocusNode.requestFocus();
      }
    });
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
    if (oldSessionId != sessionId && sessionId != null) {
      _bindSshSession(sessionId);
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
              onPointerDown: (_) => _focusInputProxy(),
              child: xterm.TerminalView(
                terminal,
                focusNode: inputFocusNode,
                hardwareKeyboardOnly: true,
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
        ],
      ),
    );
  }
}
