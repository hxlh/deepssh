import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in-memory bridge creates updates lists and deletes SSH profiles', () async {
    final bridge = InMemorySshBridgeClient();

    final created = await bridge.createProfile(
      name: 'Prod',
      host: 'example.com',
      port: 2222,
      username: 'root',
      password: 'secret',
    );

    expect(created.id, 'profile-1');
    expect(created.name, 'Prod');
    expect(created.host, 'example.com');
    expect(created.port, 2222);
    expect(created.username, 'root');
    expect(created.password, 'secret');
    expect(await bridge.listProfiles(), [created]);

    final updated = await bridge.updateProfile(
      id: created.id,
      name: 'Prod Updated',
      host: '127.0.0.1',
      port: 22,
      username: 'ubuntu',
      password: 'changed',
    );

    expect(updated.name, 'Prod Updated');
    expect(updated.host, '127.0.0.1');
    expect(updated.port, 22);
    expect(updated.username, 'ubuntu');
    expect(updated.password, 'changed');
    expect(await bridge.listProfiles(), [updated]);

    await bridge.deleteProfile(created.id);

    expect(await bridge.listProfiles(), isEmpty);
  });

  test('in-memory bridge returns a session result and output stream', () async {
    final bridge = InMemorySshBridgeClient();
    final profile = await bridge.createProfile(
      name: 'Dev',
      host: 'localhost',
      port: 22,
      username: 'dev',
      password: 'secret',
    );

    final result = await bridge.connectProfile(profile.id);

    expect(result.sessionId, 'ssh-session-1');
    expect(result.title, 'Dev');
    await expectLater(bridge.outputStream(result.sessionId), emits(isEmpty));
  });
}
