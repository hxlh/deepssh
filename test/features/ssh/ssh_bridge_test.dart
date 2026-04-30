import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SSH profile item defaults to xterm-256color', () {
    const profile = SshProfileItem(
      id: 'profile-1',
      name: 'Prod',
      host: 'example.com',
      port: 22,
      username: 'root',
      password: 'secret',
    );

    expect(SshProfileItem.defaultTermType, 'xterm-256color');
    expect(SshProfileItem.termTypeOptions, [
      'xterm',
      'xterm-color',
      'xterm-16color',
      'xterm-256color',
      'xterm-truecolor',
    ]);
    expect(profile.termType, 'xterm-256color');
  });

  test(
    'in-memory bridge creates updates lists and deletes SSH profiles',
    () async {
      final bridge = InMemorySshBridgeClient();

      final created = await bridge.createProfile(
        name: 'Prod',
        host: 'example.com',
        port: 2222,
        username: 'root',
        password: 'secret',
        termType: 'xterm-truecolor',
      );

      expect(created.id, 'profile-1');
      expect(created.name, 'Prod');
      expect(created.host, 'example.com');
      expect(created.port, 2222);
      expect(created.username, 'root');
      expect(created.password, 'secret');
      expect(created.termType, 'xterm-truecolor');
      expect(await bridge.listProfiles(), [created]);

      final updated = await bridge.updateProfile(
        id: created.id,
        name: 'Prod Updated',
        host: '127.0.0.1',
        port: 22,
        username: 'ubuntu',
        password: 'changed',
        termType: 'xterm-256color',
      );

      expect(updated.name, 'Prod Updated');
      expect(updated.host, '127.0.0.1');
      expect(updated.port, 22);
      expect(updated.username, 'ubuntu');
      expect(updated.password, 'changed');
      expect(updated.termType, 'xterm-256color');
      expect(await bridge.listProfiles(), [updated]);

      await bridge.deleteProfile(created.id);

      expect(await bridge.listProfiles(), isEmpty);
    },
  );

  test('in-memory bridge returns a session result and output stream', () async {
    final bridge = InMemorySshBridgeClient();
    final profile = await bridge.createProfile(
      name: 'Dev',
      host: 'localhost',
      port: 22,
      username: 'dev',
      password: 'secret',
      termType: 'xterm-color',
    );

    final result = await bridge.connectProfile(profile.id);

    expect(result.sessionId, 'ssh-session-1');
    expect(result.title, 'Dev');
    await expectLater(bridge.outputStream(result.sessionId), emits(isEmpty));
  });
}
