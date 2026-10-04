import 'package:deepssh/core/models/local_terminal_item.dart';
import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/core/theme/app_colors.dart';
import 'package:deepssh/features/hosts/host_tree.dart';
import 'package:deepssh/features/hosts/host_tree_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('local terminal selection uses UI selection color only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostTree(
            state: HostTreeState(),
            selectedTerminalId: 'local-terminal-1',
            onToggleHost: (_) {},
            onTerminalTap: (_) {},
            localTerminals: const [
              LocalTerminalItem(id: 'local-terminal-1', title: 'terminal1'),
            ],
            localExpanded: true,
            onToggleLocal: () {},
            onLocalTerminalTap: (_) {},
            sshProfiles: const [],
            sshSessionsByProfileId: const {},
            onSshProfileTap: (_) {},
            onSshSessionTap: (_) {},
            onEditSshSessionNote: (_) async {},
            onCloseSshSession: (_) async {},
            onCloseLocalTerminal: (_) async {},
            onDuplicateSshSession: (_) async {},
            onToggleMemoryDock: () {},
            memoryDockVisible: true,
          ),
        ),
      ),
    );

    final uiSelection = AppColors.selection;
    final terminalSelection =
        TerminalThemeSettings.commandDeck().selectionColor;

    final selectedContainer = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration && decoration.color == uiSelection;
        });
    final decoration = selectedContainer.decoration as BoxDecoration;

    expect(decoration.color, uiSelection);
    expect(decoration.color, isNot(terminalSelection));
  });
}
