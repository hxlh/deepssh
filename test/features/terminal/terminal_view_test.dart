import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/features/local_terminal/local_terminal_bridge.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/terminal/terminal_find.dart';
import 'package:deepssh/features/terminal/terminal_state.dart';
import 'package:deepssh/features/terminal/terminal_tab_shell.dart';
import 'package:deepssh/features/terminal/terminal_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/src/ui/render.dart' as xterm_render;
import 'package:xterm/xterm.dart' as xterm;

final TerminalThemeSettings _defaultTerminalTheme =
    TerminalThemeSettings.commandDeck();

const xterm.TerminalTheme _selectionPaintTestTheme = xterm.TerminalTheme(
  cursor: Colors.white,
  selection: Color(0xFFFF0000),
  foreground: Colors.white,
  background: Colors.black,
  black: Colors.black,
  red: Colors.red,
  green: Colors.green,
  yellow: Colors.yellow,
  blue: Colors.blue,
  magenta: Colors.purple,
  cyan: Colors.cyan,
  white: Colors.white,
  brightBlack: Colors.black54,
  brightRed: Colors.redAccent,
  brightGreen: Colors.greenAccent,
  brightYellow: Colors.yellowAccent,
  brightBlue: Colors.blueAccent,
  brightMagenta: Colors.purpleAccent,
  brightCyan: Colors.cyanAccent,
  brightWhite: Colors.white,
  searchHitBackground: Colors.yellow,
  searchHitBackgroundCurrent: Colors.green,
  searchHitForeground: Colors.black,
);

void main() {
  test('terminal style uses configured normal and bold font weights', () {
    const style = xterm.TerminalStyle(
      normalFontWeight: FontWeight.w300,
      boldFontWeight: FontWeight.w800,
    );

    expect(style.toTextStyle().fontWeight, FontWeight.w300);
    expect(style.toTextStyle(bold: true).fontWeight, FontWeight.w800);
  });

  test('terminal parses colon-separated truecolor foreground SGR', () {
    final terminal = xterm.Terminal();
    terminal.write('\x1b[38:2::255:128:64mA');

    final foreground = terminal.buffer.lines[0].getForeground(0);

    expect(foreground & xterm.CellColor.typeMask, xterm.CellColor.rgb);
    expect(foreground & xterm.CellColor.valueMask, 0xff8040);
  });

  test('terminal ignores incomplete extended color SGR parameters', () {
    final terminal = xterm.Terminal();

    expect(() => terminal.write('\x1b[38mA'), returnsNormally);
    expect(() => terminal.write('\x1b[48;2;16mB'), returnsNormally);

    expect(terminal.buffer.lines[0].getCodePoint(0), 'A'.codeUnitAt(0));
    expect(terminal.buffer.lines[0].getCodePoint(1), 'B'.codeUnitAt(0));
  });

  test('find session keeps highlight columns after empty terminal cells', () {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.write('prefix\x1b[20Gpingcap/tidb\r\n');
    final controller = xterm.TerminalController();
    final session = TerminalFindSession(
      terminal: terminal,
      terminalController: controller,
      searchHitBackground: Colors.blue,
      searchHitBackgroundCurrent: Colors.orange,
    );

    session.setQuery('pingcap');

    expect(session.matchCount, 1);
    final range = controller.highlights.single.range!;
    expect(range.begin.x, 19);
    expect(range.end.x, 26);

    session.dispose();
    controller.dispose();
  });

  test('find session matches queries across terminal rows', () {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.write('alpha\r\nbeta\r\n');
    final controller = xterm.TerminalController();
    final session = TerminalFindSession(
      terminal: terminal,
      terminalController: controller,
      searchHitBackground: Colors.blue,
      searchHitBackgroundCurrent: Colors.orange,
    );

    session.setQuery('alpha\r\nbeta');

    expect(session.matchCount, 1);
    expect(session.currentMatchRow, 0);
    expect(controller.highlights, hasLength(1));
    final range = controller.highlights.single.range!;
    expect(range.begin.x, 0);
    expect(range.begin.y, 0);
    expect(range.end.x, 4);
    expect(range.end.y, 1);

    session.dispose();
    controller.dispose();
  });

  test('applies foreground resolver once per visible non-empty row', () {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.resize(80, 24);
    terminal.write('INFO first line\r\n');
    terminal.write('WARN second line\r\n');
    final foregroundColors = List<Color?>.filled(2 * terminal.viewWidth, null);
    var resolverCalls = 0;

    xterm_render.applyForegroundColorResolver(
      foregroundColors,
      resolver: (row, lineText, colors, rowOffset, viewWidth) {
        resolverCalls++;
      },
      lines: terminal.buffer.lines,
      firstLine: 0,
      lastLine: 1,
      viewWidth: terminal.viewWidth,
    );

    expect(resolverCalls, 2);
  });

  testWidgets('passes terminal theme font weights to xterm view', (
    tester,
  ) async {
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: xterm.Terminal(maxLines: 3000),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme.copyWith(
              normalFontWeight: 300,
              boldFontWeight: 800,
            ),
          ),
        ),
      ),
    );

    final view = terminalView(tester);

    expect(view.textStyle.normalFontWeight, FontWeight.w300);
    expect(view.textStyle.boldFontWeight, FontWeight.w800);
  });

  testWidgets('adds extra bottom padding around terminal content', (
    tester,
  ) async {
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: xterm.Terminal(maxLines: 3000),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );

    final padding = tester.widget<Padding>(
      find.ancestor(
        of: find.byType(xterm.TerminalView),
        matching: find.byType(Padding),
      ),
    );

    expect(padding.padding, const EdgeInsets.fromLTRB(12, 12, 12, 17));
  });

  testWidgets('seeds full multi-line find query from terminal selection', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.write('alpha\r\nbeta\r\n');
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final controller = terminalView(tester).controller!;
    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(4, 1),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF, character: 'f');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final findInput = find.descendant(
      of: find.byType(TerminalFindBar),
      matching: find.byType(TextField),
    );
    final textField = tester.widget<TextField>(findInput);
    expect(textField.controller!.text, r'alpha\nbeta');
  });
  testWidgets('focuses find input when terminal find opens', (tester) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.write('needle match\r\n');
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF, character: 'f');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TerminalFindBar),
        matching: find.byType(TextField),
      ),
    );
    expect(textField.focusNode!.hasFocus, isTrue);
  });

  testWidgets('seeds find query from current terminal selection on Ctrl+F', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.write('alpha beta gamma\r\n');
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final controller = terminalView(tester).controller!;
    controller.setSelection(
      terminal.buffer.createAnchor(6, 0),
      terminal.buffer.createAnchor(10, 0),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF, character: 'f');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byType(TerminalFindBar), findsOneWidget);
    expect(find.widgetWithText(TextField, 'beta'), findsOneWidget);
  });

  testWidgets('extends drag selection from original cell after scrolling', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.resize(80, 8);
    for (var i = 0; i < 40; i++) {
      terminal.write('line ${i.toString().padLeft(2, '0')} target text\r\n');
    }
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );

    await tester.pumpWidget(
      _terminalApp(
        width: 800,
        height: 260,
        tab: tab,
        bridge: RecordingSshBridgeClient(),
        theme: _defaultTerminalTheme.copyWith(fontSize: 20),
      ),
    );
    await tester.pumpAndSettle();

    final view = terminalView(tester);
    final scrollController = view.scrollController!;
    final bottomOffset = scrollController.offset;
    final renderTerminal =
        tester.renderObject(
              find.descendant(
                of: find.byType(xterm.TerminalView),
                matching: find.byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_TerminalView',
                ),
              ),
            )
            as dynamic;
    final cellSize = renderTerminal.cellSize as Size;
    final start = Offset(8 * cellSize.width, cellSize.height * 4);
    final originalStartCell = renderTerminal.getCellOffset(start);

    renderTerminal.selectCharacters(start);
    await tester.pump();

    scrollController.jumpTo(bottomOffset - (cellSize.height * 4));
    await tester.pump();

    renderTerminal.selectCharacters(
      start,
      Offset(18 * cellSize.width, cellSize.height * 4),
    );
    await tester.pump();

    final selection = view.controller!.selection!.normalized;
    expect(selection.end.y, originalStartCell.y);
  });

  testWidgets('auto-scrolls while dragging selection near viewport edge', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.resize(80, 8);
    for (var i = 0; i < 60; i++) {
      terminal.write(
        'line ${i.toString().padLeft(2, '0')} selectable text\r\n',
      );
    }
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );

    await tester.pumpWidget(
      _terminalApp(
        width: 800,
        height: 260,
        tab: tab,
        bridge: RecordingSshBridgeClient(),
        theme: _defaultTerminalTheme.copyWith(fontSize: 20),
      ),
    );
    await tester.pumpAndSettle();

    final view = terminalView(tester);
    final scrollController = view.scrollController!;
    final initialOffset = scrollController.offset;
    final renderTerminal =
        tester.renderObject(
              find.descendant(
                of: find.byType(xterm.TerminalView),
                matching: find.byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_TerminalView',
                ),
              ),
            )
            as dynamic;
    final cellSize = renderTerminal.cellSize as Size;
    final start = renderTerminal.localToGlobal(
      Offset(8 * cellSize.width, cellSize.height * 4),
    );
    final edge = renderTerminal.localToGlobal(
      Offset(18 * cellSize.width, cellSize.height * 1),
    );

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(edge);
    await tester.pump(const Duration(milliseconds: 200));

    expect(scrollController.offset, lessThan(initialOffset));
    expect(view.controller!.selection!.normalized.begin.y, lessThan(52));

    await gesture.up();
  });

  testWidgets('paints selection at the terminal render offset', (tester) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.resize(20, 5);
    final controller = xterm.TerminalController();

    const stackKey = Key('selection-paint-offset-stack');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            key: stackKey,
            children: [
              Positioned(
                left: 40,
                top: 48,
                width: 360,
                height: 120,
                child: xterm.TerminalView(
                  terminal,
                  controller: controller,
                  hardwareKeyboardOnly: true,
                  theme: _selectionPaintTestTheme,
                  textStyle: const xterm.TerminalStyle(fontSize: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final renderTerminal =
        tester.renderObject(
              find.descendant(
                of: find.byType(xterm.TerminalView),
                matching: find.byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_TerminalView',
                ),
              ),
            )
            as dynamic;
    final cellSize = renderTerminal.cellSize as Size;
    controller.setSelection(
      terminal.buffer.createAnchor(1, 0),
      terminal.buffer.createAnchor(4, 0),
    );
    await tester.pump();

    expect(
      tester.renderObject(find.byKey(stackKey)),
      paints
        ..rect(rect: const Rect.fromLTWH(40, 48, 360, 120), color: Colors.black)
        ..rect(
          rect: Rect.fromLTWH(40, 48, cellSize.width, cellSize.height),
          color: Colors.white,
        )
        ..rect(
          rect: Rect.fromLTWH(
            40 + cellSize.width,
            48,
            cellSize.width * 3,
            cellSize.height,
          ),
          color: const Color(0xFFFF0000),
        ),
    );
  });

  testWidgets(
    'does not clamp find scroll to bottom for lower scrollback matches',
    (tester) async {
      final terminal = xterm.Terminal(maxLines: 3000);
      for (var i = 0; i < 110; i++) {
        terminal.write('line $i\r\n');
      }
      terminal.write('needle target\r\n');
      for (var i = 110; i < 130; i++) {
        terminal.write('line $i\r\n');
      }
      final tab = OpenTerminalTab.ssh(
        id: 'ssh-tab-1',
        hostName: 'host1',
        title: 'terminal1',
        sessionId: 'session-1',
        terminal: terminal,
      );

      await tester.pumpWidget(
        _terminalApp(
          width: 800,
          height: 260,
          tab: tab,
          bridge: RecordingSshBridgeClient(),
          theme: _defaultTerminalTheme.copyWith(fontSize: 20),
        ),
      );
      await tester.pumpAndSettle();

      final scrollController = terminalView(tester).scrollController!;
      final bottomOffset = scrollController.offset;
      expect(bottomOffset, greaterThan(0));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF, character: 'f');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final findInput = find.descendant(
        of: find.byType(TerminalFindBar),
        matching: find.byType(TextField),
      );
      await tester.enterText(findInput, 'needle');
      await tester.pumpAndSettle();

      expect(scrollController.offset, lessThan(bottomOffset));
    },
  );

  testWidgets('scrolls current find match into view when query changes', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.write('needle target\r\n');
    for (var i = 0; i < 80; i++) {
      terminal.write('line $i\r\n');
    }
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );

    await tester.pumpWidget(
      _terminalApp(
        width: 800,
        height: 260,
        tab: tab,
        bridge: RecordingSshBridgeClient(),
      ),
    );
    await tester.pumpAndSettle();

    final scrollController = terminalView(tester).scrollController!;
    final bottomOffset = scrollController.offset;
    expect(bottomOffset, greaterThan(0));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF, character: 'f');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final findInput = find.descendant(
      of: find.byType(TerminalFindBar),
      matching: find.byType(TextField),
    );
    await tester.enterText(findInput, 'needle');
    await tester.pumpAndSettle();

    expect(scrollController.offset, lessThan(bottomOffset));
  });

  testWidgets('positions non-macOS IME proxy at terminal cursor', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.write('prompt> ');
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    if (isMacOS) {
      expect(find.byKey(const Key('terminal-input-proxy')), findsNothing);
      return;
    }

    final terminalState = tester.state<xterm.TerminalViewState>(
      find.byType(xterm.TerminalView),
    );
    final proxyTopLeft = tester.getTopLeft(
      find.byKey(const Key('terminal-input-proxy')),
    );

    expect(proxyTopLeft.dx, terminalState.globalCursorRect.left);
    expect(proxyTopLeft.dy, terminalState.globalCursorRect.top);
  });

  testWidgets('enables text input so IME composition can enter SSH terminals', (
    tester,
  ) async {
    const tab = OpenTerminalTab(
      id: 'm1-t1',
      hostId: 'machine1',
      hostName: 'machine1',
      title: 'terminal1',
      sourceType: TerminalSourceType.remote,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: InMemorySshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );

    final terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    expect(terminalWidget.hardwareKeyboardOnly, !isMacOS);
    if (isMacOS) {
      expect(find.byKey(const Key('terminal-input-proxy')), findsNothing);
    } else {
      expect(find.byKey(const Key('terminal-input-proxy')), findsOneWidget);
    }
    expect(find.byType(xterm.TerminalView), findsOneWidget);
  });

  testWidgets('closes terminal find when Ctrl+F is pressed while open', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.write('needle match\r\n');
    final state = TerminalState(
      tabs: [
        OpenTerminalTab.ssh(
          id: 'ssh-tab-1',
          hostName: 'host1',
          title: 'terminal1',
          sessionId: 'session-1',
          terminal: terminal,
        ),
      ],
      activeTabId: 'ssh-tab-1',
    );

    await tester.pumpWidget(
      _terminalShellApp(state: state, bridge: RecordingSshBridgeClient()),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF, character: 'f');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byType(TerminalFindBar), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF, character: 'f');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byType(TerminalFindBar), findsNothing);
  });

  testWidgets('closes terminal find from the find input with Ctrl+F', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.write('needle match\r\n');
    final state = TerminalState(
      tabs: [
        OpenTerminalTab.ssh(
          id: 'ssh-tab-1',
          hostName: 'host1',
          title: 'terminal1',
          sessionId: 'session-1',
          terminal: terminal,
        ),
      ],
      activeTabId: 'ssh-tab-1',
    );

    await tester.pumpWidget(
      _terminalShellApp(state: state, bridge: RecordingSshBridgeClient()),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF, character: 'f');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final findInput = find.descendant(
      of: find.byType(TerminalFindBar),
      matching: find.byType(TextField),
    );
    await tester.tap(findInput);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF, character: 'f');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byType(TerminalFindBar), findsNothing);
  });

  testWidgets('keeps terminal find open when switching tabs', (tester) async {
    final firstTerminal = xterm.Terminal(maxLines: 3000);
    firstTerminal.write('first needle match\r\n');
    final secondTerminal = xterm.Terminal(maxLines: 3000);
    secondTerminal.write('second needle match\r\n');
    var state = TerminalState(
      tabs: [
        OpenTerminalTab.ssh(
          id: 'ssh-tab-1',
          hostName: 'host1',
          title: 'terminal1',
          sessionId: 'session-1',
          terminal: firstTerminal,
        ),
        OpenTerminalTab.ssh(
          id: 'ssh-tab-2',
          hostName: 'host2',
          title: 'terminal2',
          sessionId: 'session-2',
          terminal: secondTerminal,
        ),
      ],
      activeTabId: 'ssh-tab-1',
    );
    final bridge = RecordingSshBridgeClient();

    await tester.pumpWidget(_terminalShellApp(state: state, bridge: bridge));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF, character: 'f');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final findInput = find.descendant(
      of: find.byType(TerminalFindBar),
      matching: find.byType(TextField),
    );
    await tester.enterText(findInput, 'needle');
    await tester.pumpAndSettle();
    expect(find.byType(TerminalFindBar), findsOneWidget);
    expect(find.widgetWithText(TextField, 'needle'), findsOneWidget);

    state = state.activate('ssh-tab-2');
    await tester.pumpWidget(_terminalShellApp(state: state, bridge: bridge));
    await tester.pumpAndSettle();

    expect(find.byType(TerminalFindBar), findsOneWidget);
    expect(find.widgetWithText(TextField, 'needle'), findsOneWidget);
    final controller = terminalView(tester).controller!;
    expect(controller.highlights, hasLength(1));
    final range = controller.highlights.single.range!;
    expect(range.begin.x, 7);
    expect(range.end.x, 13);
  });

  testWidgets('restores SSH terminal history when switching tabs', (
    tester,
  ) async {
    var state = TerminalState(
      tabs: [
        OpenTerminalTab.ssh(
          id: 'ssh-tab-1',
          hostName: 'host1',
          title: 'terminal1',
          sessionId: 'session-1',
          history: 'first session\r\n',
        ),
        OpenTerminalTab.ssh(
          id: 'ssh-tab-2',
          hostName: 'host2',
          title: 'terminal2',
          sessionId: 'session-2',
          history: 'second session\r\n',
        ),
      ],
      activeTabId: 'ssh-tab-1',
    );

    await tester.pumpWidget(
      _terminalShellApp(state: state, bridge: RecordingSshBridgeClient()),
    );
    await tester.pumpAndSettle();

    state = state.activate('ssh-tab-2');
    await tester.pumpWidget(
      _terminalShellApp(state: state, bridge: RecordingSshBridgeClient()),
    );
    await tester.pumpAndSettle();

    var terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    expect(
      terminalWidget.terminal.buffer.toString(),
      contains('second session'),
    );
    expect(
      terminalWidget.terminal.buffer.toString(),
      isNot(contains('first session')),
    );

    state = state.activate('ssh-tab-1');
    await tester.pumpWidget(
      _terminalShellApp(state: state, bridge: RecordingSshBridgeClient()),
    );
    await tester.pumpAndSettle();

    terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    expect(
      terminalWidget.terminal.buffer.toString(),
      contains('first session'),
    );
    expect(
      terminalWidget.terminal.buffer.toString(),
      isNot(contains('second session')),
    );
  });

  testWidgets('reuses provided SSH terminal without replaying history', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.write('ssh prompt\r\n');
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      history: 'ssh prompt\r\n',
      terminal: terminal,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    final bufferText = terminalWidget.terminal.buffer.toString();
    expect(identical(terminalWidget.terminal, terminal), isTrue);
    expect('ssh prompt'.allMatches(bufferText), hasLength(1));
  });

  testWidgets('writes IME text input to SSH sessions', (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final bridge = RecordingSshBridgeClient();
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: bridge,
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('terminal-input-proxy')));
    await tester.pump(const Duration(seconds: 1));

    binding.testTextInput.enterText('中文');
    await binding.idle();

    expect(bridge.writes.join(), '中文');
  });

  testWidgets('writes IME text after clicking terminal surface', (
    tester,
  ) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final bridge = RecordingSshBridgeClient();
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: bridge,
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('terminal-input-proxy')));
    await tester.pump(const Duration(milliseconds: 300));

    binding.testTextInput.enterText('中文');
    await binding.idle();

    expect(bridge.writes.join(), '中文');
  });

  testWidgets(
    'copies selected terminal text on Ctrl+C without interrupting SSH',
    (tester) async {
      final bridge = RecordingSshBridgeClient();
      final terminal = xterm.Terminal(maxLines: 3000);
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              final data = Map<String, dynamic>.from(call.arguments as Map);
              copiedText = data['text'] as String?;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      terminal.write('alpha beta gamma\r\n');
      final tab = OpenTerminalTab.ssh(
        id: 'ssh-tab-1',
        hostName: 'host1',
        title: 'terminal1',
        sessionId: 'session-1',
        terminal: terminal,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              tab: tab,
              sshBridge: bridge,
              localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
              terminalThemeSettings: _defaultTerminalTheme,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('terminal-input-proxy')));
      await tester.pump(const Duration(milliseconds: 300));

      final controller = terminalView(tester).controller!;
      controller.setSelection(
        terminal.buffer.createAnchor(6, 0),
        terminal.buffer.createAnchor(10, 0),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC, character: '');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(copiedText, 'beta');
      expect(bridge.writes, isEmpty);
    },
  );

  testWidgets('copies blank terminal cells inside selected text as spaces', (
    tester,
  ) async {
    final bridge = RecordingSshBridgeClient();
    final terminal = xterm.Terminal(maxLines: 3000);
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final data = Map<String, dynamic>.from(call.arguments as Map);
            copiedText = data['text'] as String?;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    terminal.write('hello\x1b[3Cword\r\n');
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: bridge,
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('terminal-input-proxy')));
    await tester.pump(const Duration(milliseconds: 300));

    final controller = terminalView(tester).controller!;
    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(12, 0),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC, character: '');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(copiedText, 'hello   word');
    expect(bridge.writes, isEmpty);
  });

  testWidgets('sends Ctrl+C through SSH terminal input proxy', (tester) async {
    final bridge = RecordingSshBridgeClient();
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: bridge,
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('terminal-input-proxy')));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC, character: '');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(bridge.writes.join(), '');
  });

  testWidgets('does not send composing IME text before commit', (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final bridge = RecordingSshBridgeClient();
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: bridge,
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('terminal-input-proxy')));
    await tester.pump(const Duration(milliseconds: 300));

    binding.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '中文',
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await binding.idle();
    binding.testTextInput.updateEditingValue(
      const TextEditingValue(text: '中文'),
    );
    await binding.idle();

    expect(bridge.writes.join(), '中文');
  });

  testWidgets(
    'syncs current terminal size when SSH session binds after layout',
    (tester) async {
      final bridge = RecordingSshBridgeClient();
      final terminal = xterm.Terminal(maxLines: 3000);
      final pendingTab = OpenTerminalTab.ssh(
        id: 'ssh-tab-1',
        hostName: 'machine1',
        title: 'terminal1',
        terminal: terminal,
      );
      final connectedTab = pendingTab.copyWith(sessionId: 'session-1');

      await tester.pumpWidget(
        _terminalApp(width: 900, height: 600, tab: pendingTab, bridge: bridge),
      );
      await tester.pumpAndSettle();

      final terminalWidget = tester.widget<xterm.TerminalView>(
        find.byType(xterm.TerminalView),
      );
      final laidOutCols = terminalWidget.terminal.viewWidth;
      final laidOutRows = terminalWidget.terminal.viewHeight;

      await tester.pumpWidget(
        _terminalApp(
          width: 900,
          height: 600,
          tab: connectedTab,
          bridge: bridge,
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(bridge.resizeCalls, hasLength(1));
      expect(bridge.resizeCalls.single.sessionId, 'session-1');
      expect(bridge.resizeCalls.single.cols, laidOutCols);
      expect(bridge.resizeCalls.single.rows, laidOutRows);
    },
  );

  testWidgets('applies cursor style and blink settings to SSH terminal view', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final theme = _defaultTerminalTheme.copyWith(
      cursorStyle: CursorStyle.underline,
      cursorBlink: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );

    final terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    expect(terminalWidget.cursorType, xterm.TerminalCursorType.underline);
    expect(terminalWidget.alwaysShowCursor, isFalse);
    expect(
      terminalWidget.theme.selection,
      theme.selectionColor.withValues(alpha: 0.45),
    );
    expect(terminal.cursorBlinkMode, isTrue);
  });

  test('keeps underline and bar cursor painting on the active input row', () {
    final painterSource = File(
      'third_party/xterm/lib/src/ui/painter.dart',
    ).readAsStringSync();

    expect(
      painterSource,
      contains('Offset(offset.dx, offset.dy + _cellSize.height - 1)'),
    );
    expect(painterSource, contains('offset.dx + _cellSize.width'));
    expect(painterSource, contains('offset.dy + _cellSize.height - 1'));
    expect(painterSource, contains('Offset(offset.dx, offset.dy)'));
    expect(
      painterSource,
      contains('Offset(offset.dx, offset.dy + _cellSize.height)'),
    );
  });

  testWidgets('toggles terminal cursor visibility while blink is enabled', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final theme = _defaultTerminalTheme.copyWith(cursorBlink: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );

    expect(terminalView(tester).cursorBlinkVisible, isTrue);
    await tester.pump(const Duration(milliseconds: 600));
    expect(terminalView(tester).cursorBlinkVisible, isFalse);
  });

  test('reports cursor position using one-based coordinates', () {
    final output = <String>[];
    final terminal = xterm.Terminal(onOutput: output.add);

    terminal.write('\x1b[6n');

    expect(output, ['\x1b[1;1R']);
  });

  testWidgets('keeps cursor visible until 500ms after latest input', (
    tester,
  ) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final bridge = RecordingSshBridgeClient();
    final terminal = xterm.Terminal(maxLines: 3000);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final theme = _defaultTerminalTheme.copyWith(cursorBlink: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: bridge,
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('terminal-input-proxy')));
    await tester.pump(const Duration(milliseconds: 400));

    binding.testTextInput.enterText('a');
    await binding.idle();
    expect(terminalView(tester).cursorBlinkVisible, isTrue);

    await tester.pump(const Duration(milliseconds: 400));
    expect(terminalView(tester).cursorBlinkVisible, isTrue);

    await tester.pump(const Duration(milliseconds: 101));
    expect(terminalView(tester).cursorBlinkVisible, isFalse);
    expect(bridge.writes.join(), 'a');
  });
  testWidgets('keeps cursor visible while terminal output moves cursor', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final theme = _defaultTerminalTheme.copyWith(cursorBlink: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(terminalView(tester).cursorBlinkVisible, isFalse);

    terminal.write('a');
    await tester.pump();
    expect(terminalView(tester).cursorBlinkVisible, isTrue);

    await tester.pump(const Duration(milliseconds: 400));
    expect(terminalView(tester).cursorBlinkVisible, isTrue);

    await tester.pump(const Duration(milliseconds: 101));
    expect(terminalView(tester).cursorBlinkVisible, isFalse);
  });

  testWidgets('cursor blink does not override terminal hidden cursor mode', (
    tester,
  ) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final terminal = xterm.Terminal(maxLines: 3000);
    terminal.setCursorVisibleMode(false);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final theme = _defaultTerminalTheme.copyWith(cursorBlink: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('terminal-input-proxy')));

    binding.testTextInput.enterText('a');
    await binding.idle();
    expect(terminal.cursorVisibleMode, isFalse);
    await tester.pump(const Duration(milliseconds: 501));

    expect(terminal.cursorVisibleMode, isFalse);
  });

  testWidgets('stops toggling terminal cursor when blink is disabled', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final blinkingTheme = _defaultTerminalTheme.copyWith(cursorBlink: true);
    final steadyTheme = _defaultTerminalTheme.copyWith(cursorBlink: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: blinkingTheme,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(terminalView(tester).cursorBlinkVisible, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: steadyTheme,
          ),
        ),
      ),
    );
    expect(terminalView(tester).cursorBlinkVisible, isTrue);
    await tester.pump(const Duration(milliseconds: 600));
    expect(terminalView(tester).cursorBlinkVisible, isTrue);
  });

  testWidgets(
    'renders regex highlight colors without mutating terminal cells',
    (tester) async {
      final terminal = xterm.Terminal(maxLines: 3000);
      final tab = OpenTerminalTab.ssh(
        id: 'ssh-tab-1',
        hostName: 'host1',
        title: 'terminal1',
        sessionId: 'session-1',
        terminal: terminal,
      );
      final theme = _defaultTerminalTheme.copyWith(
        regexHighlights: const [
          RegexHighlight(pattern: 'ERROR', color: Color(0xFFF14C4C)),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              tab: tab,
              sshBridge: RecordingSshBridgeClient(),
              localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
              terminalThemeSettings: theme,
            ),
          ),
        ),
      );

      terminal.write('2026-04-26 ERROR request failed\r\n');
      await tester.pump();

      final line = terminal.buffer.lines[0];
      expect(
        line.getForeground(11),
        isNot(terminalRgbColor(const Color(0xFFF14C4C))),
      );
      expect(
        line.getForeground(15),
        isNot(terminalRgbColor(const Color(0xFFF14C4C))),
      );
      expect(terminalView(tester).controller!.highlights, isEmpty);
    },
  );

  testWidgets('keeps regex foreground colors aligned after empty cells', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final theme = _defaultTerminalTheme.copyWith(
      regexHighlights: const [
        RegexHighlight(pattern: r'\d+', color: Color(0xFFF5F543)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );

    terminal.write('abc\x1b[5C12 ok\r\n');
    await tester.pump();

    final terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    final lineText = terminal.buffer.lines[0].getText();
    expect(lineText, 'abc     12 ok');
    expect(regexForegroundColor(terminalWidget, 0, 7, lineText), isNull);
    expect(
      regexForegroundColor(terminalWidget, 0, 8, lineText),
      const Color(0xFFF5F543),
    );
    expect(
      regexForegroundColor(terminalWidget, 0, 9, lineText),
      const Color(0xFFF5F543),
    );
    expect(regexForegroundColor(terminalWidget, 0, 10, lineText), isNull);
  });

  testWidgets('aligns regex highlight colors after wide terminal characters', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final theme = _defaultTerminalTheme.copyWith(
      regexHighlights: const [
        RegexHighlight(pattern: r'/[^\s]+', color: Color(0xFFF5F543)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );

    terminal.write('中文 /tmp/file\r\n');
    await tester.pump();

    final terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    final lineText = terminal.buffer.lines[0].getText();
    expect(regexForegroundColor(terminalWidget, 0, 4, lineText), isNull);
    expect(
      regexForegroundColor(terminalWidget, 0, 5, lineText),
      const Color(0xFFF5F543),
    );
    expect(
      regexForegroundColor(terminalWidget, 0, 13, lineText),
      const Color(0xFFF5F543),
    );
  });

  testWidgets(
    'passes earlier regex highlight rules as higher priority foreground overlays',
    (tester) async {
      final terminal = xterm.Terminal(maxLines: 3000);
      final tab = OpenTerminalTab.ssh(
        id: 'ssh-tab-1',
        hostName: 'host1',
        title: 'terminal1',
        sessionId: 'session-1',
        terminal: terminal,
      );
      final theme = _defaultTerminalTheme.copyWith(
        regexHighlights: const [
          RegexHighlight(pattern: 'ERROR', color: Color(0xFFF14C4C)),
          RegexHighlight(pattern: 'ERROR request', color: Color(0xFFF5F543)),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              tab: tab,
              sshBridge: RecordingSshBridgeClient(),
              localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
              terminalThemeSettings: theme,
            ),
          ),
        ),
      );

      terminal.write('ERROR request failed\r\n');
      await tester.pump();

      final terminalWidget = tester.widget<xterm.TerminalView>(
        find.byType(xterm.TerminalView),
      );
      final lineText = terminal.buffer.lines[0].getText();
      expect(terminalWidget.foregroundColorResolver, isNotNull);

      expect(
        regexForegroundColor(terminalWidget, 0, 0, lineText),
        const Color(0xFFF14C4C),
      );
      expect(
        regexForegroundColor(terminalWidget, 0, 5, lineText),
        const Color(0xFFF5F543),
      );
      expect(regexForegroundColor(terminalWidget, 0, 13, lineText), isNull);
      expect(
        terminal.buffer.lines[0].getForeground(0),
        isNot(terminalRgbColor(const Color(0xFFF14C4C))),
      );
    },
  );

  testWidgets('regex setting changes repaint existing visible content', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final redTheme = _defaultTerminalTheme.copyWith(
      regexHighlights: const [
        RegexHighlight(pattern: 'ERROR', color: Color(0xFFF14C4C)),
      ],
    );
    final yellowTheme = _defaultTerminalTheme.copyWith(
      regexHighlights: const [
        RegexHighlight(pattern: 'ERROR', color: Color(0xFFF5F543)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: redTheme,
          ),
        ),
      ),
    );

    terminal.write('ERROR old\r\n');
    await tester.pump();

    var terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    expect(
      regexForegroundColor(terminalWidget, 0, 0, 'ERROR old'),
      const Color(0xFFF14C4C),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: yellowTheme,
          ),
        ),
      ),
    );

    terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    expect(
      regexForegroundColor(terminalWidget, 0, 0, 'ERROR old'),
      const Color(0xFFF5F543),
    );
    expect(
      terminal.buffer.lines[0].getForeground(0),
      isNot(terminalRgbColor(const Color(0xFFF5F543))),
    );
  });

  testWidgets('does not leave regex color residue after content changes', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final theme = _defaultTerminalTheme.copyWith(
      regexHighlights: const [
        RegexHighlight(pattern: 'ERROR', color: Color(0xFFF14C4C)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );

    terminal.write('ERROR\r');
    await tester.pump();

    var terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    expect(
      regexForegroundColor(
        terminalWidget,
        0,
        0,
        terminal.buffer.lines[0].getText(),
      ),
      const Color(0xFFF14C4C),
    );

    terminal.write('clean\r');
    await tester.pump();

    terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    final lineText = terminal.buffer.lines[0].getText();
    expect(lineText.startsWith('clean'), isTrue);
    expect(regexForegroundColor(terminalWidget, 0, 0, lineText), isNull);
    expect(
      terminal.buffer.lines[0].getForeground(0),
      isNot(terminalRgbColor(const Color(0xFFF14C4C))),
    );
  });

  test('foreground highlights are resolved before text painting', () {
    final terminal = xterm.Terminal()
      ..resize(8, 1)
      ..write('match');
    final controller = xterm.TerminalController();
    final highlight = controller.highlight(
      p1: terminal.buffer.createAnchor(1, 0),
      p2: terminal.buffer.createAnchor(4, 0),
      foregroundColor: Colors.red,
    );

    final highlights = xterm_render.createForegroundHighlightMap(
      controller.highlights,
      firstLine: 0,
      lastLine: 0,
      viewWidth: terminal.viewWidth,
    );

    expect(highlights[0], isNull);
    expect(highlights[1], Colors.red);
    expect(highlights[2], Colors.red);
    expect(highlights[3], Colors.red);
    expect(highlights[4], isNull);

    highlight.dispose();
    controller.dispose();
  });

  testWidgets('skips invalid regex highlight rules', (tester) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final theme = _defaultTerminalTheme.copyWith(
      regexHighlights: const [
        RegexHighlight(pattern: '[', color: Color(0xFFF5F543)),
        RegexHighlight(pattern: 'WARN', color: Color(0xFFF5F543)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );

    terminal.write('WARN slow request\r\n');
    await tester.pump(const Duration(milliseconds: 120));

    final terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    final lineText = terminal.buffer.lines[0].getText();
    expect(
      regexForegroundColor(terminalWidget, 0, 0, lineText),
      const Color(0xFFF5F543),
    );
    expect(
      regexForegroundColor(terminalWidget, 0, 3, lineText),
      const Color(0xFFF5F543),
    );
    expect(
      terminal.buffer.lines[0].getForeground(0),
      isNot(terminalRgbColor(const Color(0xFFF5F543))),
    );
    expect(terminalView(tester).controller!.highlights, isEmpty);
  });

  testWidgets('colors regex matches as terminal output arrives', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final theme = _defaultTerminalTheme.copyWith(
      regexHighlights: const [
        RegexHighlight(pattern: 'ERROR', color: Color(0xFFF14C4C)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );

    terminal.write('path/a.dart\r\n');
    terminal.write('path/b.dart\r\n');
    terminal.write('path/c.dart ERROR\r\n');
    await tester.pump();

    final terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    final lineText = terminal.buffer.lines[2].getText();
    expect(
      regexForegroundColor(terminalWidget, 2, 12, lineText),
      const Color(0xFFF14C4C),
    );
    expect(
      regexForegroundColor(terminalWidget, 2, 16, lineText),
      const Color(0xFFF14C4C),
    );
    expect(
      terminal.buffer.lines[2].getForeground(12),
      isNot(terminalRgbColor(const Color(0xFFF14C4C))),
    );
    expect(terminalView(tester).controller!.highlights, isEmpty);
  });

  testWidgets('colors regex matches after scrollback trims old lines', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 40);
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'host1',
      title: 'terminal1',
      sessionId: 'session-1',
      terminal: terminal,
    );
    final theme = _defaultTerminalTheme.copyWith(
      regexHighlights: const [
        RegexHighlight(pattern: 'ERROR', color: Color(0xFFF14C4C)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );

    for (var i = 0; i < 40; i++) {
      terminal.write('old/$i\r\n');
    }
    await tester.pump();

    terminal.write('new/a ERROR\r\nnew/b ERROR\r\n');
    await tester.pump();

    final firstNewLine = terminal.buffer.lines.length - 3;
    final secondNewLine = terminal.buffer.lines.length - 2;
    final terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    final firstText = terminal.buffer.lines[firstNewLine].getText();
    final secondText = terminal.buffer.lines[secondNewLine].getText();
    expect(
      regexForegroundColor(terminalWidget, firstNewLine, 6, firstText),
      const Color(0xFFF14C4C),
    );
    expect(
      regexForegroundColor(terminalWidget, secondNewLine, 6, secondText),
      const Color(0xFFF14C4C),
    );
    expect(
      terminal.buffer.lines[firstNewLine].getForeground(6),
      isNot(terminalRgbColor(const Color(0xFFF14C4C))),
    );
  });

  testWidgets('emits plain current-line preview after terminal changes', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final previews = <String>[];
    final tab = OpenTerminalTab.local(
      id: 'local-tab-1',
      title: 'terminal1',
      terminal: terminal,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
            onPreviewLabelChanged: previews.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    terminal.write(r'PS C:\src> npm run dev');
    await tester.pump();

    expect(previews, [r'PS C:\src> npm run dev']);
  });

  testWidgets('does not emit preview for whitespace-only current lines', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final previews = <String>[];
    final tab = OpenTerminalTab.local(
      id: 'local-tab-1',
      title: 'terminal1',
      terminal: terminal,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            tab: tab,
            sshBridge: RecordingSshBridgeClient(),
            localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
            terminalThemeSettings: _defaultTerminalTheme,
            onPreviewLabelChanged: previews.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    terminal.write('ready');
    await tester.pump();
    terminal.write('\r\n   ');
    await tester.pump();

    expect(previews, ['ready']);
  });

  testWidgets('truncates preview labels to 100 characters by character count', (
    tester,
  ) async {
    final terminal = xterm.Terminal(maxLines: 3000);
    final previews = <String>[];
    final longLine = '终' * 120;
    final tab = OpenTerminalTab.local(
      id: 'local-tab-1',
      title: 'terminal1',
      terminal: terminal,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 3600,
            height: 600,
            child: TerminalView(
              tab: tab,
              sshBridge: RecordingSshBridgeClient(),
              localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
              terminalThemeSettings: _defaultTerminalTheme,
              onPreviewLabelChanged: previews.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    terminal.resize(300, 24);
    terminal.write(longLine);
    await tester.pump();

    expect(previews.single.characters.length, 100);
    expect(previews.single, '终' * 100);
  });

  testWidgets('coalesces rapid SSH terminal viewport resize events', (
    tester,
  ) async {
    final bridge = RecordingSshBridgeClient();
    final tab = OpenTerminalTab.ssh(
      id: 'ssh-tab-1',
      hostName: 'machine1',
      title: 'terminal1',
      sessionId: 'session-1',
    );

    await tester.pumpWidget(
      _terminalApp(width: 900, height: 600, tab: tab, bridge: bridge),
    );
    await tester.pumpAndSettle();
    bridge.resizeCalls.clear();

    final terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    terminalWidget.terminal.resize(80, 24);
    terminalWidget.terminal.resize(81, 24);
    terminalWidget.terminal.resize(82, 24);
    await tester.pump(const Duration(milliseconds: 120));

    expect(bridge.resizeCalls, hasLength(1));
    expect(bridge.resizeCalls.single.sessionId, 'session-1');
    expect(bridge.resizeCalls.single.cols, 82);
    expect(bridge.resizeCalls.single.rows, 24);
  });
}

int terminalRgbColor(Color color) {
  return xterm.CellColor.rgb | (color.toARGB32() & xterm.CellColor.valueMask);
}

Color? regexForegroundColor(
  xterm.TerminalView terminalWidget,
  int row,
  int column,
  String lineText,
) {
  final foregroundColors = List<Color?>.filled(
    terminalWidget.terminal.viewWidth,
    null,
  );
  terminalWidget.foregroundColorResolver!(
    row,
    lineText,
    foregroundColors,
    0,
    terminalWidget.terminal.viewWidth,
  );
  return foregroundColors[column];
}

xterm.TerminalView terminalView(WidgetTester tester) {
  return tester.widget<xterm.TerminalView>(find.byType(xterm.TerminalView));
}

Widget _terminalApp({
  required double width,
  required double height,
  required OpenTerminalTab tab,
  required SshBridgeClient bridge,
  TerminalThemeSettings? theme,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: height,
        child: TerminalView(
          tab: tab,
          sshBridge: bridge,
          localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
          terminalThemeSettings: theme ?? _defaultTerminalTheme,
        ),
      ),
    ),
  );
}

Widget _terminalShellApp({
  required TerminalState state,
  required SshBridgeClient bridge,
}) {
  return MaterialApp(
    home: Scaffold(
      body: TerminalTabShell(
        state: state,
        onSelectTab: (_) {},
        onCloseTab: (_) {},
        onReorderTab: (_, __) {},
        sshBridge: bridge,
        localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
        terminalThemeSettings: _defaultTerminalTheme,
      ),
    ),
  );
}

class RecordingSshBridgeClient implements SshBridgeClient {
  final resizeCalls = <ResizeCall>[];
  final writes = <String>[];

  @override
  Future<void> closeSession(String sessionId) async {}

  @override
  Future<SshConnectionResult> connectProfile(
    String id, {
    String? password,
    String? passphrase,
    int? rows,
    int? cols,
  }) async {
    return const SshConnectionResult(
      sessionId: 'session-1',
      title: 'terminal1',
    );
  }

  @override
  Future<SshProfileItem> createProfile({
    required String name,
    required String host,
    required int port,
    required String username,
    required SshAuthMode authMode,
    required String password,
    required String privateKeyPath,
    required String termType,
  }) async {
    return SshProfileItem(
      id: 'profile-1',
      name: name,
      host: host,
      port: port,
      username: username,
      authMode: authMode,
      password: password,
      privateKeyPath: privateKeyPath,
      termType: termType,
    );
  }

  @override
  Future<void> deleteProfile(String id) async {}

  @override
  Future<List<SshProfileItem>> listProfiles() async => const [];

  @override
  Stream<List<int>> outputStream(String sessionId) => const Stream.empty();

  @override
  Future<void> resizeSession({
    required String sessionId,
    required int rows,
    required int cols,
  }) async {
    resizeCalls.add(ResizeCall(sessionId: sessionId, rows: rows, cols: cols));
  }

  @override
  Future<SshProfileItem> updateProfile({
    required String id,
    required String name,
    required String host,
    required int port,
    required String username,
    required SshAuthMode authMode,
    required String password,
    required String privateKeyPath,
    required String termType,
  }) async {
    return SshProfileItem(
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      authMode: authMode,
      password: password,
      privateKeyPath: privateKeyPath,
      termType: termType,
    );
  }

  @override
  Future<void> writeToSession(String sessionId, List<int> data) async {
    writes.add(utf8.decode(data));
  }

  @override
  Future<SshConnectionResult> duplicateSession(String sessionId) async {
    return const SshConnectionResult(
      sessionId: 'ssh-session-dup',
      title: 'duplicated',
    );
  }
}

class ResizeCall {
  const ResizeCall({
    required this.sessionId,
    required this.rows,
    required this.cols,
  });

  final String sessionId;
  final int rows;
  final int cols;
}
