import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/widgets/deck_widgets.dart';
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

  Widget page({
    List<SshProfileItem> profiles = const [profile],
    String? errorMessage,
    VoidCallback? onAdd,
    ValueChanged<SshProfileItem>? onConnect,
    ValueChanged<SshProfileItem>? onEdit,
    ValueChanged<SshProfileItem>? onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SshProfilesPage(
          profiles: profiles,
          errorMessage: errorMessage,
          onAdd: onAdd ?? () {},
          onConnect: onConnect ?? (_) {},
          onEdit: onEdit ?? (_) {},
          onDelete: onDelete ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('renders SSH profile rows and wires row actions', (tester) async {
    SshProfileItem? connected;
    SshProfileItem? edited;
    SshProfileItem? deleted;
    var addTapped = false;

    await tester.pumpWidget(
      page(
        onAdd: () => addTapped = true,
        onConnect: (value) => connected = value,
        onEdit: (value) => edited = value,
        onDelete: (value) => deleted = value,
      ),
    );

    expect(find.text('连接配置'), findsOneWidget);
    expect(find.text('Production'), findsOneWidget);
    expect(find.text('root@example.com:22'), findsOneWidget);

    await tester.tap(find.text('新增 SSH 配置'));
    await tester.pumpAndSettle();
    expect(addTapped, isTrue);

    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();
    expect(connected, profile);

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(edited, profile);

    await tester.tap(find.text('删除').first);
    await tester.pumpAndSettle();
    // The confirm dialog repeats the label, so target it inside the dialog.
    await tester.tap(
      find.descendant(of: find.byType(DeckDialog), matching: find.text('删除')),
    );
    await tester.pumpAndSettle();
    expect(deleted, profile);
  });

  testWidgets('filters rows by search text and auth mode', (tester) async {
    const keyProfile = SshProfileItem(
      id: 'p2',
      name: 'Bastion',
      host: 'jump.example.net',
      port: 2222,
      username: 'ops',
      privateKeyPath: '/home/ops/.ssh/id_ed25519',
      authMode: SshAuthMode.privateKey,
    );

    await tester.pumpWidget(page(profiles: const [profile, keyProfile]));

    expect(find.text('Production'), findsOneWidget);
    expect(find.text('Bastion'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'bastion');
    await tester.pumpAndSettle();
    expect(find.text('Production'), findsNothing);
    expect(find.text('Bastion'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auth-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('私钥').last);
    await tester.pumpAndSettle();
    expect(find.text('Production'), findsNothing);
    expect(find.text('Bastion'), findsOneWidget);
  });

  testWidgets('shows an empty state when nothing matches', (tester) async {
    await tester.pumpWidget(page());
    await tester.enterText(find.byType(TextField).first, 'nothing-here');
    await tester.pumpAndSettle();

    expect(find.text('没有匹配的 SSH 配置'), findsOneWidget);
    expect(find.text('Production'), findsNothing);
  });

  testWidgets('surfaces a load error without hiding the table', (tester) async {
    await tester.pumpWidget(page(errorMessage: '配置文件读取失败'));

    expect(find.text('配置文件读取失败'), findsOneWidget);
    expect(find.text('Production'), findsOneWidget);
  });
}
