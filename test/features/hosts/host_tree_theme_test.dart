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
    AppColors.selection = const Color(0xFF123456);
    AppColors.applyTerminal(
      TerminalThemeSettings.commandDeck().copyWith(
        selectionColor: const Color(0xFFFF00FF),
      ),
    );

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
            onOpenThemeConfig: () {},
            onDuplicateSshSession: (_) async {},
            themeConfigActive: false,
            onOpenDiagnostics: () {},
            diagnosticsActive: false,
          ),
        ),
      ),
    );

    final selectedContainer = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.color == const Color(0xFF123456);
        });
    final decoration = selectedContainer.decoration as BoxDecoration;

    expect(decoration.color, const Color(0xFF123456));
    expect(decoration.color, isNot(const Color(0xFFFF00FF)));
  });
}
