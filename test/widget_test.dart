import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/main.dart';
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
}
