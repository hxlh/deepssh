import 'package:flutter/material.dart';

import '../../core/widgets/deck_widgets.dart';
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
    required this.authMode,
    required this.password,
    required this.privateKeyPath,
    required this.termType,
  });

  final String name;
  final String host;
  final int port;
  final String username;
  final SshAuthMode authMode;
  final String password;
  final String privateKeyPath;
  final String termType;
}

class _SshProfileFormPageState extends State<SshProfileFormPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController hostController;
  late final TextEditingController portController;
  late final TextEditingController usernameController;
  late final TextEditingController passwordController;
  late final TextEditingController privateKeyPathController;
  final nameFocusNode = FocusNode(debugLabel: 'Name');
  final hostFocusNode = FocusNode(debugLabel: 'Host');
  final portFocusNode = FocusNode(debugLabel: 'Port');
  final usernameFocusNode = FocusNode(debugLabel: 'Username');
  final authModeFocusNode = FocusNode(debugLabel: 'Authentication');
  final passwordFocusNode = FocusNode(debugLabel: 'Password');
  final privateKeyPathFocusNode = FocusNode(debugLabel: 'Private Key Path');
  final termTypeFocusNode = FocusNode(debugLabel: 'Terminal Type');
  late SshAuthMode selectedAuthMode;
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
    privateKeyPathController = TextEditingController(
      text: profile?.privateKeyPath ?? '',
    );
    selectedAuthMode = profile?.authMode ?? SshAuthMode.password;
    selectedTermType = profile?.termType ?? SshProfileItem.defaultTermType;
  }

  @override
  void dispose() {
    nameController.dispose();
    hostController.dispose();
    portController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    privateKeyPathController.dispose();
    nameFocusNode.dispose();
    hostFocusNode.dispose();
    portFocusNode.dispose();
    usernameFocusNode.dispose();
    authModeFocusNode.dispose();
    passwordFocusNode.dispose();
    privateKeyPathFocusNode.dispose();
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
      return '必填';
    }
    return null;
  }

  String? validatePort(String? value) {
    final requiredError = requiredText(value);
    if (requiredError != null) return requiredError;
    final port = int.tryParse(value!.trim());
    if (port == null || port < 1 || port > 65535) {
      return '端口无效';
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
        authMode: selectedAuthMode,
        password: passwordController.text,
        privateKeyPath: privateKeyPathController.text.trim(),
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DeckEyebrow('SSH'),
                      DeckTitle(isEdit ? '编辑 SSH 配置' : '新增 SSH 配置'),
                    ],
                  ),
                ),
                DeckButton(
                  label: '返回',
                  style: DeckButtonStyle.ghost,
                  icon: Icons.arrow_back,
                  onPressed: widget.onCancel,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Focus(
              onKeyEvent: (_, event) =>
                  handleFieldKey(event, null, hostFocusNode),
              child: TextFormField(
                focusNode: nameFocusNode,
                controller: nameController,
                decoration: const InputDecoration(labelText: '名称'),
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
                decoration: const InputDecoration(labelText: '主机'),
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
                decoration: const InputDecoration(labelText: '端口'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => usernameFocusNode.requestFocus(),
                validator: validatePort,
              ),
            ),
            const SizedBox(height: 12),
            Focus(
              onKeyEvent: (_, event) =>
                  handleFieldKey(event, portFocusNode, authModeFocusNode),
              child: TextFormField(
                focusNode: usernameFocusNode,
                controller: usernameController,
                decoration: const InputDecoration(labelText: '用户名'),
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => authModeFocusNode.requestFocus(),
                validator: requiredText,
              ),
            ),
            const SizedBox(height: 12),
            Focus(
              onKeyEvent: (_, event) => handleFieldKey(
                event,
                usernameFocusNode,
                selectedAuthMode == SshAuthMode.password
                    ? passwordFocusNode
                    : privateKeyPathFocusNode,
              ),
              child: DropdownButtonFormField<SshAuthMode>(
                focusNode: authModeFocusNode,
                initialValue: selectedAuthMode,
                decoration: const InputDecoration(labelText: '认证方式'),
                items: const [
                  DropdownMenuItem(
                    value: SshAuthMode.password,
                    child: Text('密码'),
                  ),
                  DropdownMenuItem(
                    value: SshAuthMode.privateKey,
                    child: Text('私钥'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedAuthMode = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            if (selectedAuthMode == SshAuthMode.password)
              Focus(
                onKeyEvent: (_, event) =>
                    handleFieldKey(event, authModeFocusNode, termTypeFocusNode),
                child: TextFormField(
                  focusNode: passwordFocusNode,
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: '密码'),
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => termTypeFocusNode.requestFocus(),
                ),
              )
            else
              Focus(
                onKeyEvent: (_, event) =>
                    handleFieldKey(event, authModeFocusNode, termTypeFocusNode),
                child: TextFormField(
                  focusNode: privateKeyPathFocusNode,
                  controller: privateKeyPathController,
                  decoration: const InputDecoration(labelText: '私钥路径'),
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => termTypeFocusNode.requestFocus(),
                  validator: requiredText,
                ),
              ),
            const SizedBox(height: 12),
            Focus(
              onKeyEvent: (_, event) => handleFieldKey(
                event,
                selectedAuthMode == SshAuthMode.password
                    ? passwordFocusNode
                    : privateKeyPathFocusNode,
                null,
              ),
              child: DropdownButtonFormField<String>(
                focusNode: termTypeFocusNode,
                initialValue: selectedTermType,
                decoration: const InputDecoration(labelText: '终端类型'),
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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DeckButton(label: '取消', onPressed: widget.onCancel),
                const SizedBox(width: 8),
                DeckButton(
                  label: isEdit ? '保存' : '创建',
                  style: DeckButtonStyle.solid,
                  onPressed: save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
