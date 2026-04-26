import 'dart:convert';
import 'dart:io';

import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/terminal/terminal_state.dart';
import 'package:deepssh/features/terminal/terminal_tab_shell.dart';
import 'package:deepssh/features/terminal/terminal_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart' as xterm;

final TerminalThemeSettings _defaultTerminalTheme =
    TerminalThemeSettings.commandDeck();

void main() {
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
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );

    final terminalWidget = tester.widget<xterm.TerminalView>(
      find.byType(xterm.TerminalView),
    );
    expect(terminalWidget.hardwareKeyboardOnly, isTrue);
    expect(find.byKey(const Key('terminal-input-proxy')), findsOneWidget);
    expect(find.byType(xterm.TerminalView), findsOneWidget);
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
            terminalThemeSettings: _defaultTerminalTheme,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(xterm.TerminalView));
    await tester.pump(const Duration(milliseconds: 300));

    binding.testTextInput.enterText('中文');
    await binding.idle();

    expect(bridge.writes.join(), '中文');
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
            terminalThemeSettings: steadyTheme,
          ),
        ),
      ),
    );
    expect(terminalView(tester).cursorBlinkVisible, isTrue);
    await tester.pump(const Duration(milliseconds: 600));
    expect(terminalView(tester).cursorBlinkVisible, isTrue);
  });

  testWidgets('highlights terminal output that matches regex rules', (
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
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );

    terminal.write('2026-04-26 ERROR request failed\r\n');
    await tester.pump(const Duration(milliseconds: 120));

    final controller = terminalView(tester).controller;
    expect(controller, isNotNull);
    expect(controller!.highlights, hasLength(1));
    final range = controller.highlights.single.range!;
    expect(range.begin.x, 11);
    expect(range.end.x, 16);
    expect(
      controller.highlights.single.foregroundColor,
      const Color(0xFFF14C4C),
    );
    expect(controller.highlights.single.backgroundColor, isNull);
  });

  testWidgets('skips invalid regex highlight rules', (
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
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );

    terminal.write('WARN slow request\r\n');
    await tester.pump(const Duration(milliseconds: 120));

    final controller = terminalView(tester).controller!;
    expect(controller.highlights, hasLength(1));
    expect(controller.highlights.single.range!.begin.x, 0);
    expect(controller.highlights.single.range!.end.x, 4);
  });

  testWidgets('debounces regex highlighting during rapid terminal output', (
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
            terminalThemeSettings: theme,
          ),
        ),
      ),
    );

    terminal.write('path/a.dart\r\n');
    terminal.write('path/b.dart\r\n');
    terminal.write('path/c.dart ERROR\r\n');
    await tester.pump();

    final controller = terminalView(tester).controller!;
    expect(controller.highlights, isEmpty);

    await tester.pump(const Duration(milliseconds: 120));

    expect(controller.highlights, hasLength(1));
    expect(controller.highlights.single.range!.begin.x, 12);
    expect(controller.highlights.single.range!.end.x, 17);
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

xterm.TerminalView terminalView(WidgetTester tester) {
  return tester.widget<xterm.TerminalView>(find.byType(xterm.TerminalView));
}

Widget _terminalApp({
  required double width,
  required double height,
  required OpenTerminalTab tab,
  required SshBridgeClient bridge,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: height,
        child: TerminalView(
          tab: tab,
          sshBridge: bridge,
          terminalThemeSettings: _defaultTerminalTheme,
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
        sshBridge: bridge,
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
  Future<SshConnectionResult> connectProfile(String id) async {
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
    required String password,
  }) async {
    return SshProfileItem(
      id: 'profile-1',
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
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
    required String password,
  }) async {
    return SshProfileItem(
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
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
