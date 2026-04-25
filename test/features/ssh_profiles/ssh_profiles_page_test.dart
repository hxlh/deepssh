import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/features/ssh_profiles/ssh_profiles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = SshProfileItem(
    id: 'p1',
    name: 'Production',
    host: 'example.com',
    port: 22,
    username: 'root',
    password: 'secret',
  );

  testWidgets('renders SSH profile actions', (tester) async {
    SshProfileItem? connected;
    SshProfileItem? edited;
    SshProfileItem? deleted;
    var addTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfilesPage(
            profiles: const [profile],
            errorMessage: null,
            onAdd: () => addTapped = true,
            onConnect: (profile) => connected = profile,
            onEdit: (profile) => edited = profile,
            onDelete: (profile) => deleted = profile,
          ),
        ),
      ),
    );

    expect(find.text('Production'), findsOneWidget);
    expect(find.text('root@example.com:22'), findsOneWidget);

    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();
    expect(addTapped, isTrue);

    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();
    expect(connected, profile);

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(edited, profile);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, profile);
  });
}
