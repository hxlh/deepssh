import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/theme/theme_bridge.dart';
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSshBridge extends InMemorySshBridgeClient {
  @override
  Future<List<SshProfileItem>> listProfiles() async => [
    SshProfileItem(
      id: 'p1',
      name: 'Server A',
      host: 'a.example.com',
      port: 22,
      username: 'user',
      password: '',
    ),
    SshProfileItem(
      id: 'p2',
      name: 'Server B',
      host: 'b.example.com',
      port: 22,
      username: 'user',
      password: '',
    ),
  ];
}

class _FakeThemeBridge extends InMemoryThemeBridgeClient {}

void main() {
  testWidgets('profiles display after loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchPage(
          sshBridge: _FakeSshBridge(),
          themeBridge: _FakeThemeBridge(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Server A'), findsOneWidget);
    expect(find.text('Server B'), findsOneWidget);
  });
}
