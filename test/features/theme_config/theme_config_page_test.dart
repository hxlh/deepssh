import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/features/theme_config/theme_config_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('command deck terminal theme includes common log regex rules', () {
    final patterns = TerminalThemeSettings.commandDeck()
        .regexHighlights
        .map((highlight) => highlight.pattern)
        .toList();

    expect(patterns, contains('ERROR|FATAL|Exception|Traceback'));
    expect(patterns, contains('WARN|WARNING'));
    expect(patterns, contains(r'\b[45]\d\d\b'));
    expect(patterns, contains(r'\b\d+ms\b|\b\d+\.\d+s\b'));
  });

  testWidgets('text input changes are emitted as the user types', (tester) async {
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
        RegexHighlight(pattern: 'ERROR', color: Color(0xFFF14C4C)),
        RegexHighlight(pattern: 'WARN', color: Color(0xFFF5F543)),
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
}
