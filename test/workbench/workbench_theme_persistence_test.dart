import 'dart:async';

import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/theme/theme_bridge.dart';
import 'package:deepssh/workbench/widgets/app_topbar.dart';
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

    await tester.tap(find.byKey(appNavKey(AppSection.theme)));
    await tester.pumpAndSettle();
    expect(find.text('主题配置'), findsWidgets);
    expect(find.textContaining('#FAF9F5'), findsWidgets);
    await tester.tap(find.text('#FAF9F5').first);
    await tester.pumpAndSettle();
    final hexField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == '#FAF9F5',
    );
    expect(hexField, findsOneWidget);
    await tester.enterText(hexField, '#123456');
    await tester.pumpAndSettle();
    // Close the picker, then commit the draft with 保存主题.
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-save')));
    await tester.pumpAndSettle();

    expect(themeBridge.savedUi.last.background, const Color(0xFF123456));
  });

  testWidgets('serializes theme saves so the latest edit persists', (
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

    await tester.tap(find.byKey(appNavKey(AppSection.theme)));
    await tester.pumpAndSettle();

    Future<void> chooseSize(String label) async {
      await tester.tap(find.byKey(const ValueKey('ui-size-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await chooseSize('15 px');
    await chooseSize('14 px');
    await tester.tap(find.byKey(const ValueKey('theme-save')));
    await tester.pump();
    expect(themeBridge.pendingSaves, hasLength(1));

    // The terminal callback queued a second save behind the first one; the
    // queued pass must carry the latest draft, not the value from before.
    themeBridge.completeNextSave();
    await tester.pump();
    await tester.pump();
    expect(themeBridge.pendingSaves, hasLength(1));
    expect(themeBridge.pendingSaves.single.ui.fontSize, 14);

    themeBridge.completeNextSave();
    await tester.pump();
    expect(themeBridge.completedUi.last.fontSize, 14);
  });
}

class RecordingThemeBridgeClient implements ThemeBridgeClient {
  final savedUi = <UiThemeSettings>[];
  final savedTerminal = <TerminalThemeSettings>[];

  @override
  Future<({UiThemeSettings ui, TerminalThemeSettings terminal})>
  loadTheme() async {
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
  Future<({UiThemeSettings ui, TerminalThemeSettings terminal})>
  loadTheme() async {
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
