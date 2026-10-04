import 'package:deepssh/core/theme/app_colors.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldEnableVmService', () {
    test('returns true when --vm is present', () {
      expect(shouldEnableVmService(['--vm']), isTrue);
    });

    test('returns false when --vm is absent', () {
      expect(shouldEnableVmService(['--debug']), isFalse);
    });

    test('ignores unknown arguments while detecting --vm', () {
      expect(shouldEnableVmService(['--profile', '--vm', '--other']), isTrue);
    });
  });

  testWidgets(
    'app boots into the DeepSSH workbench with add connection action',
    (tester) async {
      await tester.pumpWidget(DeepSshApp(sshBridge: InMemorySshBridgeClient()));

      expect(find.text('EXPLORER'), findsOneWidget);
      expect(find.text('新增连接'), findsOneWidget);
    },
  );

  testWidgets('app boots on the fixed prototype theme', (tester) async {
    await tester.pumpWidget(DeepSshApp(sshBridge: InMemorySshBridgeClient()));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('EXPLORER'));
    final theme = Theme.of(context);

    // The theme page is gone: no loaded preset, just the paper palette.
    expect(theme.colorScheme.surface, AppColors.panel);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });
}
