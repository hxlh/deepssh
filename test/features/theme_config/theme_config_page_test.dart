import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/features/theme_config/theme_config_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
