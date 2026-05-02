import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/features/ssh_profiles/ssh_profile_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('validates required SSH profile fields', (tester) async {
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormPage(
            onCancel: () {},
            onSaved: (_) => saved = true,
          ),
        ),
      ),
    );

    await tester.enterText(find.bySemanticsLabel('Port'), '');
    await tapFormButton(tester, 'Create');
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsWidgets);
    expect(saved, isFalse);
  });

  testWidgets('saves default terminal type for new SSH profile', (
    tester,
  ) async {
    SshProfileDraft? savedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormPage(
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await fillRequiredFields(tester);
    await tapFormButton(tester, 'Create');
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
          body: SshProfileFormPage(
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await fillRequiredFields(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('xterm-truecolor').last);
    await tester.pumpAndSettle();
    await tapFormButton(tester, 'Create');
    await tester.pumpAndSettle();

    expect(savedDraft?.termType, 'xterm-truecolor');
  });

  testWidgets('edit SSH profile shows existing terminal type', (tester) async {
    SshProfileDraft? savedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormPage(
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

    await tapFormButton(tester, 'Update');
    await tester.pumpAndSettle();

    expect(savedDraft?.termType, 'xterm-color');
  });

  testWidgets('shows terminal type selector below password field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormPage(onCancel: () {}, onSaved: (_) {}),
        ),
      ),
    );

    final passwordTop = tester.getTopLeft(find.bySemanticsLabel('Password')).dy;
    final terminalTypeTop = tester
        .getTopLeft(find.byType(DropdownButtonFormField<String>))
        .dy;

    expect(terminalTypeTop, greaterThan(passwordTop));
  });

  testWidgets('auth dropdown switches visible credential fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormPage(onCancel: () {}, onSaved: (_) {}),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Password'), findsOneWidget);
    expect(find.bySemanticsLabel('Private Key Path'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<SshAuthMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private Key').last);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Password'), findsNothing);
    expect(find.bySemanticsLabel('Private Key Path'), findsOneWidget);
  });

  testWidgets('password auth allows saving an empty password', (tester) async {
    SshProfileDraft? savedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormPage(
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await fillBaseFields(tester);
    await tapFormButton(tester, 'Create');
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
          body: SshProfileFormPage(
            onCancel: () {},
            onSaved: (draft) => savedDraft = draft,
          ),
        ),
      ),
    );

    await fillBaseFields(tester);
    await tester.tap(find.byType(DropdownButtonFormField<SshAuthMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private Key').last);
    await tester.pumpAndSettle();
    await tapFormButton(tester, 'Create');
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsOneWidget);
    expect(savedDraft, isNull);

    await tester.enterText(
      find.bySemanticsLabel('Private Key Path'),
      '/home/root/.ssh/id_ed25519',
    );
    await tapFormButton(tester, 'Create');
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
          body: SshProfileFormPage(onCancel: () {}, onSaved: (_) {}),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Name'));
    await tester.pump();
    expect(primaryFocusLabel(), 'Name');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(primaryFocusLabel(), 'Host');
  });

  testWidgets('moves focus to previous SSH profile field on single Shift Tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormPage(onCancel: () {}, onSaved: (_) {}),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Host'));
    await tester.pump();
    expect(primaryFocusLabel(), 'Host');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(primaryFocusLabel(), 'Name');
  });

  testWidgets('disables text suggestions on SSH profile text fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SshProfileFormPage(onCancel: () {}, onSaved: (_) {}),
        ),
      ),
    );

    expect(textFieldByLabel('Name').enableSuggestions, isFalse);
    expect(textFieldByLabel('Name').autocorrect, isFalse);
    expect(textFieldByLabel('Host').enableSuggestions, isFalse);
    expect(textFieldByLabel('Host').autocorrect, isFalse);
    expect(textFieldByLabel('Username').enableSuggestions, isFalse);
    expect(textFieldByLabel('Username').autocorrect, isFalse);
  });
}

Future<void> fillRequiredFields(WidgetTester tester) async {
  await fillBaseFields(tester);
  await tester.enterText(find.bySemanticsLabel('Password'), 'secret');
}

Future<void> fillBaseFields(WidgetTester tester) async {
  await tester.enterText(find.bySemanticsLabel('Name'), 'Prod');
  await tester.enterText(find.bySemanticsLabel('Host'), 'example.com');
  await tester.enterText(find.bySemanticsLabel('Port'), '22');
  await tester.enterText(find.bySemanticsLabel('Username'), 'root');
}

Future<void> tapFormButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(ElevatedButton, label).first;
  await tester.scrollUntilVisible(
    button,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(button);
}

TextField textFieldByLabel(String label) {
  return find
          .byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.labelText == label,
          )
          .evaluate()
          .single
          .widget
      as TextField;
}

String? primaryFocusLabel() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  final textField = context.findAncestorWidgetOfExactType<TextField>();
  return textField?.decoration?.labelText;
}
