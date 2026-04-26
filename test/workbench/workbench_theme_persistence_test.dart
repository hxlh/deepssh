import 'dart:async';

import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/theme/theme_bridge.dart';
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('persists the latest UI theme settings when a color changes', (
    tester,
  ) async {
    final themeBridge = RecordingThemeBridgeClient();

    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchPage(
          sshBridge: InMemorySshBridgeClient(),
          themeBridge: themeBridge,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('主题配置'));
    await tester.pumpAndSettle();
    expect(find.text('主题配置'), findsWidgets);
    expect(find.textContaining('#1E1E1E'), findsWidgets);
    await tester.tap(find.text('#1E1E1E').first);
    await tester.pumpAndSettle();
    final hexField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == '#1E1E1E',
    );
    expect(hexField, findsOneWidget);
    await tester.enterText(hexField, '#123456');
    await tester.pumpAndSettle();

    expect(themeBridge.savedUi.last.background, const Color(0xFF123456));
  });

  testWidgets('serializes theme saves so the latest typed value persists', (
    tester,
  ) async {
    final themeBridge = ControlledThemeBridgeClient();

    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchPage(
          sshBridge: InMemorySshBridgeClient(),
          themeBridge: themeBridge,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('主题配置'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Inter'),
      'A',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is EditableText && widget.controller.text == 'A',
      ).first,
      'AB',
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is EditableText && widget.controller.text == 'AB',
      ),
      findsOneWidget,
    );
    expect(themeBridge.pendingSaves, hasLength(1));

    themeBridge.completeNextSave();
    await tester.pump();
    await tester.pump();
    expect(themeBridge.pendingSaves, hasLength(1));
    expect(themeBridge.pendingSaves.single.ui.fontFamily, 'AB');

    themeBridge.completeNextSave();
    await tester.pump();
    expect(themeBridge.completedUi.last.fontFamily, 'AB');
  });
}

class RecordingThemeBridgeClient implements ThemeBridgeClient {
  final savedUi = <UiThemeSettings>[];
  final savedTerminal = <TerminalThemeSettings>[];

  @override
  Future<({UiThemeSettings ui, TerminalThemeSettings terminal})> loadTheme() async {
    return (
      ui: UiThemeSettings.commandDeck(),
      terminal: TerminalThemeSettings.commandDeck(),
    );
  }

  @override
  Future<void> saveTheme({
    required UiThemeSettings ui,
    required TerminalThemeSettings terminal,
  }) async {
    savedUi.add(ui);
    savedTerminal.add(terminal);
  }
}

class ControlledThemeBridgeClient implements ThemeBridgeClient {
  final pendingSaves = <PendingThemeSave>[];
  final completedUi = <UiThemeSettings>[];

  @override
  Future<({UiThemeSettings ui, TerminalThemeSettings terminal})> loadTheme() async {
    return (
      ui: UiThemeSettings.commandDeck(),
      terminal: TerminalThemeSettings.commandDeck(),
    );
  }

  @override
  Future<void> saveTheme({
    required UiThemeSettings ui,
    required TerminalThemeSettings terminal,
  }) {
    final pending = PendingThemeSave(ui, terminal);
    pendingSaves.add(pending);
    return pending.completer.future.then((_) {
      completedUi.add(ui);
    });
  }

  void completeNextSave() {
    final pending = pendingSaves.removeAt(0);
    pending.completer.complete();
  }
}

class PendingThemeSave {
  PendingThemeSave(this.ui, this.terminal);

  final UiThemeSettings ui;
  final TerminalThemeSettings terminal;
  final completer = Completer<void>();
}
