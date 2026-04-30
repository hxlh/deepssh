import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/features/theme_config/theme_config_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('command deck terminal theme includes common log regex rules', () {
    final patterns = TerminalThemeSettings.commandDeck().regexHighlights
        .map((highlight) => highlight.pattern)
        .toList();

    expect(patterns, contains('ERROR|FATAL|Exception|Traceback'));
    expect(patterns, contains('WARN|WARNING'));
    expect(patterns, contains(r'\b[45]\d\d\b'));
    expect(patterns, contains(r'\b\d+ms\b|\b\d+\.\d+s\b'));
  });

  test('command deck regex rules include readable notes', () {
    final highlights = TerminalThemeSettings.commandDeck().regexHighlights;

    expect(highlights.first.pattern, 'ERROR|FATAL|Exception|Traceback');
    expect(highlights.first.note, '错误日志');
    expect(
      highlights.map((highlight) => highlight.note),
      containsAll(['警告日志', '成功状态', 'HTTP 错误', '耗时', 'IP 地址', 'UUID']),
    );
  });

  test('regex highlight copyWith preserves and updates note', () {
    const highlight = RegexHighlight(
      pattern: 'ERROR',
      color: Color(0xFFF14C4C),
      note: '错误日志',
    );

    expect(highlight.copyWith(pattern: 'WARN').note, '错误日志');
    expect(highlight.copyWith(note: '警告日志').note, '警告日志');
  });

  testWidgets('text input changes are emitted as the user types', (
    tester,
  ) async {
    UiThemeSettings? savedUi;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThemeConfigPage(
            uiSettings: UiThemeSettings.commandDeck(),
            terminalSettings: TerminalThemeSettings.commandDeck(),
            onUiSettingsChanged: (settings) => savedUi = settings,
            onTerminalSettingsChanged: (_) {},
            onBack: () {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Inter'),
      'Fira Sans',
    );
    await tester.pump();

    expect(savedUi?.fontFamily, 'Fira Sans');
  });

  testWidgets('updates displayed values when parent settings change', (
    tester,
  ) async {
    final commandDeck = UiThemeSettings.commandDeck();
    final loaded = commandDeck.copyWith(fontFamily: 'Loaded Font');
    var currentSettings = commandDeck;

    Widget app() {
      return MaterialApp(
        home: Scaffold(
          body: ThemeConfigPage(
            uiSettings: currentSettings,
            terminalSettings: TerminalThemeSettings.commandDeck(),
            onUiSettingsChanged: (settings) => currentSettings = settings,
            onTerminalSettingsChanged: (_) {},
            onBack: () {},
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    expect(find.widgetWithText(TextFormField, 'Inter'), findsOneWidget);

    currentSettings = loaded;
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'Loaded Font'), findsOneWidget);
  });

  testWidgets('removes regex highlight rules from terminal settings', (
    tester,
  ) async {
    TerminalThemeSettings? savedTerminal;
    final terminalSettings = TerminalThemeSettings.commandDeck().copyWith(
      regexHighlights: const [
        RegexHighlight(
          pattern: 'ERROR',
          color: Color(0xFFF14C4C),
          note: '错误日志',
        ),
        RegexHighlight(pattern: 'WARN', color: Color(0xFFF5F543), note: '警告日志'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThemeConfigPage(
            uiSettings: UiThemeSettings.commandDeck(),
            terminalSettings: terminalSettings,
            onUiSettingsChanged: (_) {},
            onTerminalSettingsChanged: (settings) => savedTerminal = settings,
            onBack: () {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.byTooltip('移除正则规则').first);
    await tester.tap(find.byTooltip('移除正则规则').first);
    await tester.pump();

    expect(savedTerminal?.regexHighlights, hasLength(1));
    expect(savedTerminal?.regexHighlights.single.pattern, 'WARN');
  });

  testWidgets('updates regex highlight notes from terminal settings', (
    tester,
  ) async {
    TerminalThemeSettings? savedTerminal;
    final terminalSettings = TerminalThemeSettings.commandDeck().copyWith(
      regexHighlights: const [
        RegexHighlight(
          pattern: 'ERROR',
          color: Color(0xFFF14C4C),
          note: '错误日志',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThemeConfigPage(
            uiSettings: UiThemeSettings.commandDeck(),
            terminalSettings: terminalSettings,
            onUiSettingsChanged: (_) {},
            onTerminalSettingsChanged: (settings) => savedTerminal = settings,
            onBack: () {},
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, '错误日志'), '异常');
    await tester.pump();

    expect(savedTerminal?.regexHighlights, hasLength(1));
    expect(savedTerminal?.regexHighlights.single.pattern, 'ERROR');
    expect(
      savedTerminal?.regexHighlights.single.color,
      const Color(0xFFF14C4C),
    );
    expect(savedTerminal?.regexHighlights.single.note, '异常');
  });

  testWidgets('reorders regex highlight rules from terminal settings', (
    tester,
  ) async {
    TerminalThemeSettings? savedTerminal;
    final terminalSettings = TerminalThemeSettings.commandDeck().copyWith(
      regexHighlights: const [
        RegexHighlight(
          pattern: 'ERROR',
          color: Color(0xFFF14C4C),
          note: '错误日志',
        ),
        RegexHighlight(pattern: 'WARN', color: Color(0xFFF5F543), note: '警告日志'),
        RegexHighlight(pattern: 'INFO', color: Color(0xFF23D18B), note: '普通日志'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThemeConfigPage(
            uiSettings: UiThemeSettings.commandDeck(),
            terminalSettings: terminalSettings,
            onUiSettingsChanged: (_) {},
            onTerminalSettingsChanged: (settings) => savedTerminal = settings,
            onBack: () {},
          ),
        ),
      ),
    );

    final reorderable = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    reorderable.onReorder(0, 3);
    await tester.pump();

    expect(
      savedTerminal?.regexHighlights.map((highlight) => highlight.pattern),
      ['WARN', 'INFO', 'ERROR'],
    );
  });

  testWidgets('keeps regex highlight input focused while settings rebuild', (
    tester,
  ) async {
    var terminalSettings = TerminalThemeSettings.commandDeck().copyWith(
      regexHighlights: const [
        RegexHighlight(pattern: '', color: Color(0xFFF14C4C), note: ''),
      ],
    );

    Widget app() {
      return MaterialApp(
        home: Scaffold(
          body: ThemeConfigPage(
            uiSettings: UiThemeSettings.commandDeck(),
            terminalSettings: terminalSettings,
            onUiSettingsChanged: (_) {},
            onTerminalSettingsChanged: (settings) =>
                terminalSettings = settings,
            onBack: () {},
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    final regexFields = find.descendant(
      of: find.byType(ReorderableListView),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(regexFields.first);
    await tester.tap(regexFields.first);
    await tester.enterText(regexFields.first, 'E');
    await tester.pumpWidget(app());
    await tester.pump();

    expect(terminalSettings.regexHighlights.single.pattern, 'E');
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('adds regex highlight rule with empty note', (tester) async {
    TerminalThemeSettings? savedTerminal;
    final terminalSettings = TerminalThemeSettings.commandDeck().copyWith(
      regexHighlights: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThemeConfigPage(
            uiSettings: UiThemeSettings.commandDeck(),
            terminalSettings: terminalSettings,
            onUiSettingsChanged: (_) {},
            onTerminalSettingsChanged: (settings) => savedTerminal = settings,
            onBack: () {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('添加规则'));
    await tester.tap(find.text('添加规则'));
    await tester.pump();

    expect(savedTerminal?.regexHighlights, hasLength(1));
    expect(savedTerminal?.regexHighlights.single.pattern, '');
    expect(savedTerminal?.regexHighlights.single.note, '');
    expect(
      savedTerminal?.regexHighlights.single.color,
      const Color(0xFFFFFFFF),
    );
  });
}
