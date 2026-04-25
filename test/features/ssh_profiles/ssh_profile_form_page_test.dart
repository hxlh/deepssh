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
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsWidgets);
    expect(saved, isFalse);
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
