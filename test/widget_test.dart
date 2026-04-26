import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/theme/theme_bridge.dart';
import 'package:deepssh/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'app boots into the DeepSSH workbench with add connection action',
    (tester) async {
      await tester.pumpWidget(DeepSshApp(sshBridge: InMemorySshBridgeClient()));

      expect(find.text('EXPLORER'), findsOneWidget);
      expect(find.text('新增连接'), findsOneWidget);
    },
  );

  testWidgets('applies loaded UI font settings to the app theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      DeepSshApp(
        sshBridge: InMemorySshBridgeClient(),
        themeBridge: FixedThemeBridgeClient(
          ui: UiThemeSettings.commandDeck().copyWith(
            fontFamily: 'Fira Sans',
            fontSize: 17,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.text('EXPLORER'));
    final style = Theme.of(context).textTheme.bodyMedium;

    expect(style?.fontFamily, 'Fira Sans');
    expect(style?.fontSize, 17);
  });
}

class FixedThemeBridgeClient implements ThemeBridgeClient {
  const FixedThemeBridgeClient({required this.ui});

  final UiThemeSettings ui;

  @override
  Future<({UiThemeSettings ui, TerminalThemeSettings terminal})>
  loadTheme() async {
    return (ui: ui, terminal: TerminalThemeSettings.commandDeck());
  }

  @override
  Future<void> saveTheme({
    required UiThemeSettings ui,
    required TerminalThemeSettings terminal,
  }) async {}
}
