import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/core/widgets/deck_widgets.dart';
import 'package:deepssh/features/ssh_profiles/ssh_profile_form_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('validates required SSH profile fields', (tester) async {
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormDrawer(
            onCancel: () {},
            onSaved: (_) => saved = true,
          ),
        ),
      ),
    );

    await tester.enterText(find.bySemanticsLabel('端口'), '');
    await tapFormButton(tester, '创建');
    await tester.pumpAndSettle();

    expect(find.text('必填'), findsWidgets);
    expect(saved, isFalse);
  });

  testWidgets('saves default terminal type for new SSH profile', (
    tester,
  ) async {
    SshProfileDraft? savedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormDrawer(
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await fillRequiredFields(tester);
    await tapFormButton(tester, '创建');
    await tester.pumpAndSettle();

    expect(savedDraft?.termType, 'xterm-256color');
  });

  testWidgets('saves selected terminal type for new SSH profile', (
    tester,
  ) async {
    SshProfileDraft? savedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormDrawer(
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await fillRequiredFields(tester);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('xterm-truecolor').last);
    await tester.pumpAndSettle();
    await tapFormButton(tester, '创建');
    await tester.pumpAndSettle();

    expect(savedDraft?.termType, 'xterm-truecolor');
  });

  testWidgets('edit SSH profile shows existing terminal type', (tester) async {
    SshProfileDraft? savedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormDrawer(
            profile: const SshProfileItem(
              id: 'profile-1',
              name: 'Prod',
              host: 'example.com',
              port: 22,
              username: 'root',
              password: 'secret',
              termType: 'xterm-color',
            ),
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    expect(find.text('xterm-color'), findsOneWidget);

    await tapFormButton(tester, '保存');
    await tester.pumpAndSettle();

    expect(savedDraft?.termType, 'xterm-color');
  });

  testWidgets('shows terminal type selector below password field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormDrawer(onCancel: () {}, onSaved: (_) {}),
        ),
      ),
    );

    final passwordTop = tester.getTopLeft(find.bySemanticsLabel('密码')).dy;
    final terminalTypeTop = tester
        .getTopLeft(find.byType(DropdownButton<String>))
        .dy;

    expect(terminalTypeTop, greaterThan(passwordTop));
  });

  testWidgets('auth dropdown switches visible credential fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormDrawer(onCancel: () {}, onSaved: (_) {}),
        ),
      ),
    );

    expect(find.bySemanticsLabel('密码'), findsOneWidget);
    expect(find.bySemanticsLabel('私钥路径'), findsNothing);

    await tester.tap(find.byType(DropdownButton<SshAuthMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('私钥').last);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('密码'), findsNothing);
    expect(find.bySemanticsLabel('私钥路径'), findsOneWidget);
  });

  testWidgets('password auth allows saving an empty password', (tester) async {
    SshProfileDraft? savedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormDrawer(
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await fillBaseFields(tester);
    await tapFormButton(tester, '创建');
    await tester.pumpAndSettle();

    expect(savedDraft?.authMode, SshAuthMode.password);
    expect(savedDraft?.password, '');
    expect(savedDraft?.privateKeyPath, '');
  });

  testWidgets('private key auth requires a key path', (tester) async {
    SshProfileDraft? savedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormDrawer(
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await fillBaseFields(tester);
    await tester.tap(find.byType(DropdownButton<SshAuthMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('私钥').last);
    await tester.pumpAndSettle();
    await tapFormButton(tester, '创建');
    await tester.pumpAndSettle();

    expect(find.text('必填'), findsOneWidget);
    expect(savedDraft, isNull);

    await tester.enterText(
      find.bySemanticsLabel('私钥路径'),
      '/home/root/.ssh/id_ed25519',
    );
    await tapFormButton(tester, '创建');
    await tester.pumpAndSettle();

    expect(savedDraft?.authMode, SshAuthMode.privateKey);
    expect(savedDraft?.password, '');
    expect(savedDraft?.privateKeyPath, '/home/root/.ssh/id_ed25519');
  });

  testWidgets('moves focus to next SSH profile field on single Tab key down', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormDrawer(onCancel: () {}, onSaved: (_) {}),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('名称'));
    await tester.pump();
    expect(primaryFocusLabel(), '名称');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(primaryFocusLabel(), '主机');
  });

  testWidgets('moves focus to previous SSH profile field on single Shift Tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormDrawer(onCancel: () {}, onSaved: (_) {}),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('主机'));
    await tester.pump();
    expect(primaryFocusLabel(), '主机');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(primaryFocusLabel(), '名称');
  });

  testWidgets('disables text suggestions on SSH profile text fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormDrawer(onCancel: () {}, onSaved: (_) {}),
        ),
      ),
    );

    expect(textFieldByLabel('名称').enableSuggestions, isFalse);
    expect(textFieldByLabel('名称').autocorrect, isFalse);
    expect(textFieldByLabel('主机').enableSuggestions, isFalse);
    expect(textFieldByLabel('主机').autocorrect, isFalse);
    expect(textFieldByLabel('用户名').enableSuggestions, isFalse);
    expect(textFieldByLabel('用户名').autocorrect, isFalse);
  });
}

Future<void> fillRequiredFields(WidgetTester tester) async {
  await fillBaseFields(tester);
  await tester.enterText(find.bySemanticsLabel('密码'), 'secret');
}

Future<void> fillBaseFields(WidgetTester tester) async {
  await tester.enterText(find.bySemanticsLabel('名称'), 'Prod');
  await tester.enterText(find.bySemanticsLabel('主机'), 'example.com');
  await tester.enterText(find.bySemanticsLabel('端口'), '22');
  await tester.enterText(find.bySemanticsLabel('用户名'), 'root');
}

Future<void> tapFormButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(DeckButton, label).last;
  await tester.scrollUntilVisible(
    button,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(button);
}

/// The drawer labels its control with [Semantics] rather than
/// `decoration.labelText`, so tests reach fields through the same handle
/// assistive tech reads.
EditableText textFieldByLabel(String label) {
  final editable = find.descendant(
    of: find.bySemanticsLabel(label),
    matching: find.byType(EditableText),
    matchRoot: true,
  );
  return editable.evaluate().single.widget as EditableText;
}

/// Nearest labelled [Semantics] ancestor — the drawer's own field label.
String? primaryFocusLabel() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  String? nearest;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is Semantics) {
      final label = widget.properties.label;
      if (label != null && label.isNotEmpty) {
        nearest = label;
        return false;
      }
    }
    return true;
  });
  return nearest;
}
