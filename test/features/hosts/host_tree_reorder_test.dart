import 'package:deepssh/core/models/local_terminal_item.dart';
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

Widget _hostTree({
  List<LocalTerminalItem> localTerminals = const [],
  List<SshProfileItem> sshProfiles = const [],
  Map<String, List<SshSessionItem>> sshSessionsByProfileId = const {},
  List<String> sectionOrder = const [],
  ValueChanged<List<String>>? onSectionOrderChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: HostTree(
        state: HostTreeState(),
        selectedTerminalId: null,
        onToggleHost: (_) {},
        onTerminalTap: (_) {},
        localTerminals: localTerminals,
        localExpanded: true,
        onToggleLocal: () {},
        onLocalTerminalTap: (_) {},
        sshProfiles: sshProfiles,
        sshSessionsByProfileId: sshSessionsByProfileId,
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
        onReorderSessions: (_, __, ___) {},
        onReorderLocalTerminals: (_, __) {},
        sectionOrder: sectionOrder,
        onSectionOrderChanged: onSectionOrderChanged,
      ),
    ),
  );
}

void main() {
  testWidgets('HostTree accepts reorder callbacks', (tester) async {
    final profile = _profile('p1', 'Server A');
    final sessionA = _session('s1', 'p1');
    final sessionB = _session('s2', 'p1');

    await tester.pumpWidget(
      _hostTree(
        sshProfiles: [profile],
        sshSessionsByProfileId: {
          'p1': [sessionA, sessionB],
        },
      ),
    );

    expect(find.text('Server A'), findsOneWidget);
    expect(find.text('session-s1'), findsOneWidget);
    expect(find.text('session-s2'), findsOneWidget);
  });

  testWidgets('local header aligns with ssh profile headers', (tester) async {
    await tester.pumpWidget(
      _hostTree(
        localTerminals: const [
          LocalTerminalItem(id: 'local-terminal-1', title: 'terminal1'),
        ],
        sshProfiles: [_profile('p1', 'Server A')],
      ),
    );

    expect(
      tester.getTopLeft(find.byIcon(Icons.laptop)).dx,
      tester.getTopLeft(find.byIcon(Icons.computer)).dx,
    );
  });

  testWidgets('local section reorder emits updated section order', (
    tester,
  ) async {
    List<String>? emittedOrder;

    await tester.pumpWidget(
      _hostTree(
        localTerminals: const [
          LocalTerminalItem(id: 'local-terminal-1', title: 'terminal1'),
        ],
        sshProfiles: [_profile('p1', 'Server A')],
        sectionOrder: const ['local', 'profile:p1'],
        onSectionOrderChanged: (order) => emittedOrder = order,
      ),
    );

    await tester.drag(find.text('Local'), const Offset(0, 48));
    await tester.pumpAndSettle();

    expect(emittedOrder, const ['profile:p1', 'local']);
  });

  testWidgets('ssh profile id local does not replace the local section', (
    tester,
  ) async {
    await tester.pumpWidget(
      _hostTree(
        localTerminals: const [
          LocalTerminalItem(id: 'local-terminal-1', title: 'terminal1'),
        ],
        sshProfiles: [_profile('local', 'Server A')],
      ),
    );

    expect(find.text('Server A'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
  });
}
