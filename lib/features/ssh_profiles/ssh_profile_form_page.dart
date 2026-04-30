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
    required this.termType,
  });

  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String termType;
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
  final termTypeFocusNode = FocusNode(debugLabel: 'Terminal Type');
  late String selectedTermType;

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
    selectedTermType = profile?.termType ?? SshProfileItem.defaultTermType;
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
    termTypeFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult handleFieldKey(
    KeyEvent event,
    FocusNode? previousFocusNode,
    FocusNode? nextFocusNode,
  ) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      final targetFocusNode = HardwareKeyboard.instance.isShiftPressed
          ? previousFocusNode
          : nextFocusNode;
      if (targetFocusNode != null) {
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
        termType: selectedTermType,
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
        child: ListView(
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
                  handleFieldKey(event, usernameFocusNode, termTypeFocusNode),
              child: TextFormField(
                focusNode: passwordFocusNode,
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => termTypeFocusNode.requestFocus(),
                validator: requiredText,
              ),
            ),
            const SizedBox(height: 12),
            Focus(
              onKeyEvent: (_, event) =>
                  handleFieldKey(event, passwordFocusNode, null),
              child: DropdownButtonFormField<String>(
                focusNode: termTypeFocusNode,
                value: selectedTermType,
                decoration: const InputDecoration(labelText: 'Terminal Type'),
                items: [
                  for (final option in SshProfileItem.termTypeOptions)
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedTermType = value;
                  });
                },
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
