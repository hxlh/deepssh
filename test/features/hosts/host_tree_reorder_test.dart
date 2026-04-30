import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/models/ssh_session_item.dart';
import 'package:deepssh/features/hosts/host_tree.dart';
import 'package:deepssh/features/hosts/host_tree_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SshProfileItem _profile(String id, String name) => SshProfileItem(
  id: id,
  name: name,
  host: 'host-$id',
  port: 22,
  username: 'user',
  password: '',
);

SshSessionItem _session(String id, String profileId) => SshSessionItem(
  id: id,
  profileId: profileId,
  hostName: 'host-$profileId',
  title: 'session-$id',
);

void main() {
  testWidgets('HostTree accepts reorder callbacks', (tester) async {
    final profile = _profile('p1', 'Server A');
    final sessionA = _session('s1', 'p1');
    final sessionB = _session('s2', 'p1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HostTree(
            state: HostTreeState(),
            selectedTerminalId: null,
            onToggleHost: (_) {},
            onTerminalTap: (_) {},
            localTerminals: const [],
            localExpanded: false,
            onToggleLocal: () {},
            onLocalTerminalTap: (_) {},
            sshProfiles: [profile],
            sshSessionsByProfileId: {
              'p1': [sessionA, sessionB],
            },
            onSshProfileTap: (_) {},
            onSshSessionTap: (_) {},
            onEditSshSessionNote: (_) async {},
            onCloseSshSession: (_) async {},
            onCloseLocalTerminal: (_) async {},
            onOpenThemeConfig: () {},
            onDuplicateSshSession: (_) async {},
            themeConfigActive: false,
            onReorderProfiles: (_, __) {},
            onReorderSessions: (_, __, ___) {},
            onReorderLocalTerminals: (_, __) {},
          ),
        ),
      ),
    );

    expect(find.text('Server A'), findsOneWidget);
    expect(find.text('session-s1'), findsOneWidget);
    expect(find.text('session-s2'), findsOneWidget);
  });
}
