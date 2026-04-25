import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/ssh_profile_item.dart';

class SshProfileFormPage extends StatefulWidget {
  const SshProfileFormPage({
    super.key,
    this.profile,
    required this.onCancel,
    required this.onSaved,
  });

  final SshProfileItem? profile;
  final VoidCallback onCancel;
  final ValueChanged<SshProfileDraft> onSaved;

  @override
  State<SshProfileFormPage> createState() => _SshProfileFormPageState();
}

class SshProfileDraft {
  const SshProfileDraft({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
}

class _SshProfileFormPageState extends State<SshProfileFormPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController hostController;
  late final TextEditingController portController;
  late final TextEditingController usernameController;
  late final TextEditingController passwordController;
  final nameFocusNode = FocusNode(debugLabel: 'Name');
  final hostFocusNode = FocusNode(debugLabel: 'Host');
  final portFocusNode = FocusNode(debugLabel: 'Port');
  final usernameFocusNode = FocusNode(debugLabel: 'Username');
  final passwordFocusNode = FocusNode(debugLabel: 'Password');

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    nameController = TextEditingController(text: profile?.name ?? '');
    hostController = TextEditingController(text: profile?.host ?? '');
    portController = TextEditingController(
      text: profile?.port.toString() ?? '22',
    );
    usernameController = TextEditingController(text: profile?.username ?? '');
    passwordController = TextEditingController(text: profile?.password ?? '');
    for (final node in [
      nameFocusNode,
      hostFocusNode,
      portFocusNode,
      usernameFocusNode,
      passwordFocusNode,
    ]) {
      node.addListener(() {
        logDebug(
          '[ssh-form:focus] ${node.debugLabel}=${node.hasFocus} '
          'primary=${FocusManager.instance.primaryFocus?.debugLabel}',
        );
      });
    }
    nameController.addListener(() => logFieldEditing('Name', nameController));
    hostController.addListener(() => logFieldEditing('Host', hostController));
    portController.addListener(() => logFieldEditing('Port', portController));
    usernameController.addListener(
      () => logFieldEditing('Username', usernameController),
    );
    passwordController.addListener(
      () => logFieldEditing('Password', passwordController),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    hostController.dispose();
    portController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    nameFocusNode.dispose();
    hostFocusNode.dispose();
    portFocusNode.dispose();
    usernameFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  void logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  void logFieldEditing(String label, TextEditingController controller) {
    final value = controller.value;
    logDebug(
      '[ssh-form:edit] $label text=${jsonEncode(value.text)} '
      'selection=${value.selection.start}-${value.selection.end} '
      'composing=${value.composing.start}-${value.composing.end} '
      'valid=${value.composing.isValid} collapsed=${value.composing.isCollapsed}',
    );
  }

  KeyEventResult handleFieldKey(
    KeyEvent event,
    FocusNode? previousFocusNode,
    FocusNode? nextFocusNode,
  ) {
    logDebug(
      '[ssh-form:key] focus=${FocusManager.instance.primaryFocus?.debugLabel} '
      'type=${event.runtimeType} logical=${event.logicalKey.keyLabel} '
      'character=${jsonEncode(event.character)} '
      'ctrl=${HardwareKeyboard.instance.isControlPressed} '
      'alt=${HardwareKeyboard.instance.isAltPressed} '
      'shift=${HardwareKeyboard.instance.isShiftPressed} '
      'meta=${HardwareKeyboard.instance.isMetaPressed}',
    );
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      final targetFocusNode = HardwareKeyboard.instance.isShiftPressed
          ? previousFocusNode
          : nextFocusNode;
      if (targetFocusNode != null) {
        logDebug('[ssh-form:tab] target=${targetFocusNode.debugLabel}');
        targetFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? validatePort(String? value) {
    final requiredError = requiredText(value);
    if (requiredError != null) return requiredError;
    final port = int.tryParse(value!.trim());
    if (port == null || port < 1 || port > 65535) {
      return 'Invalid port';
    }
    return null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    widget.onSaved(
      SshProfileDraft(
        name: nameController.text.trim(),
        host: hostController.text.trim(),
        port: int.parse(portController.text.trim()),
        username: usernameController.text.trim(),
        password: passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.profile != null;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Edit SSH Profile' : 'New SSH Profile',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Focus(
              onKeyEvent: (_, event) =>
                  handleFieldKey(event, null, hostFocusNode),
              child: TextFormField(
                focusNode: nameFocusNode,
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => hostFocusNode.requestFocus(),
                validator: requiredText,
              ),
            ),
            const SizedBox(height: 12),
            Focus(
              onKeyEvent: (_, event) =>
                  handleFieldKey(event, nameFocusNode, portFocusNode),
              child: TextFormField(
                focusNode: hostFocusNode,
                controller: hostController,
                decoration: const InputDecoration(labelText: 'Host'),
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => portFocusNode.requestFocus(),
                validator: requiredText,
              ),
            ),
            const SizedBox(height: 12),
            Focus(
              onKeyEvent: (_, event) =>
                  handleFieldKey(event, hostFocusNode, usernameFocusNode),
              child: TextFormField(
                focusNode: portFocusNode,
                controller: portController,
                decoration: const InputDecoration(labelText: 'Port'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => usernameFocusNode.requestFocus(),
                validator: validatePort,
              ),
            ),
            const SizedBox(height: 12),
            Focus(
              onKeyEvent: (_, event) =>
                  handleFieldKey(event, portFocusNode, passwordFocusNode),
              child: TextFormField(
                focusNode: usernameFocusNode,
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => passwordFocusNode.requestFocus(),
                validator: requiredText,
              ),
            ),
            const SizedBox(height: 12),
            Focus(
              onKeyEvent: (_, event) =>
                  handleFieldKey(event, usernameFocusNode, null),
              child: TextFormField(
                focusNode: passwordFocusNode,
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => save(),
                validator: requiredText,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: save,
                  child: Text(isEdit ? 'Update' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
