import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/core/theme/app_colors.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/theme/theme_bridge.dart';
import 'package:deepssh/main.dart';
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('base font size scales the workbench UI text', (tester) async {
    addTearDown(() => AppColors.applyUi(UiThemeSettings.commandDeck()));

    await tester.pumpWidget(
      DeepSshApp(
        sshBridge: InMemorySshBridgeClient(),
        themeBridge: InMemoryThemeBridgeClient(),
      ),
    );
    await tester.pumpAndSettle();

    double uiScale() =>
        MediaQuery.textScalerOf(
          tester.element(find.byType(WorkbenchPage)),
        ).scale(100) /
        100;

    // The deck default (13) renders exactly like today.
    expect(uiScale(), closeTo(1.0, 0.001));

    // Saving a bigger base size re-derives the scaler without a restart.
    AppColors.applyUi(UiThemeSettings.commandDeck().copyWith(fontSize: 18));
    await tester.pump();
    expect(uiScale(), closeTo(18 / 13, 0.001));
  });
}
