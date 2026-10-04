import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/deck_drawer.dart';
import '../../core/widgets/deck_fields.dart';
import '../../core/widgets/deck_widgets.dart';

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

/// SSH profile form, drawn as the prototype's right-hand drawer.
///
/// The connections list stays mounted behind the scrim, so cancelling drops
/// straight back to the list the user opened the form from.
class SshProfileFormDrawer extends StatefulWidget {
  const SshProfileFormDrawer({
    super.key,
    this.profile,
    required this.onCancel,
    required this.onSaved,
  });

  final SshProfileItem? profile;
  final VoidCallback onCancel;
  final ValueChanged<SshProfileDraft> onSaved;

  @override
  State<SshProfileFormDrawer> createState() => _SshProfileFormDrawerState();
}

class _SshProfileFormDrawerState extends State<SshProfileFormDrawer> {
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
  final authModeFocusNode = FocusNode(debugLabel: 'Auth Mode');
  final passwordFocusNode = FocusNode(debugLabel: 'Password');
  final privateKeyPathFocusNode = FocusNode(debugLabel: 'Private Key Path');
  final termTypeFocusNode = FocusNode(debugLabel: 'Term Type');
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
      final target = HardwareKeyboard.instance.isShiftPressed
          ? previousFocusNode
          : nextFocusNode;
      if (target != null) {
        target.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return '必填';
    return null;
  }

  String? validatePort(String? value) {
    final requiredError = requiredText(value);
    if (requiredError != null) return requiredError;
    final port = int.tryParse(value!.trim());
    if (port == null || port < 1 || port > 65535) return '端口无效';
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
    return DeckDrawer(
      kicker: 'SSH Profile',
      title: isEdit ? '编辑 SSH 配置' : '新增 SSH 配置',
      onClose: widget.onCancel,
      footer: Row(
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
      child: DeckDrawerBody(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                onKeyEvent: (_, event) =>
                    handleFieldKey(event, null, hostFocusNode),
                child: DeckTextField(
                  label: '名称',
                  controller: nameController,
                  hintText: '例如 prod-web-01',
                  focusNode: nameFocusNode,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => hostFocusNode.requestFocus(),
                  validator: requiredText,
                ),
              ),
              const SizedBox(height: 15),
              DeckFieldRow(
                children: [
                  Focus(
                    onKeyEvent: (_, event) =>
                        handleFieldKey(event, nameFocusNode, portFocusNode),
                    child: DeckTextField(
                      label: '主机',
                      controller: hostController,
                      hintText: '10.24.8.11',
                      focusNode: hostFocusNode,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => portFocusNode.requestFocus(),
                      validator: requiredText,
                    ),
                  ),
                  Focus(
                    onKeyEvent: (_, event) =>
                        handleFieldKey(event, hostFocusNode, usernameFocusNode),
                    child: DeckTextField(
                      label: '端口',
                      controller: portController,
                      focusNode: portFocusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [digitsOnly()],
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => usernameFocusNode.requestFocus(),
                      validator: validatePort,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Focus(
                onKeyEvent: (_, event) =>
                    handleFieldKey(event, portFocusNode, authModeFocusNode),
                child: DeckTextField(
                  label: '用户名',
                  controller: usernameController,
                  hintText: 'deploy',
                  focusNode: usernameFocusNode,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => authModeFocusNode.requestFocus(),
                  validator: requiredText,
                ),
              ),
              const SizedBox(height: 15),
              Focus(
                onKeyEvent: (_, event) => handleFieldKey(
                  event,
                  usernameFocusNode,
                  selectedAuthMode == SshAuthMode.password
                      ? passwordFocusNode
                      : privateKeyPathFocusNode,
                ),
                child: DeckSelect<SshAuthMode>(
                  label: '认证方式',
                  value: selectedAuthMode,
                  focusNode: authModeFocusNode,
                  items: const [SshAuthMode.password, SshAuthMode.privateKey],
                  itemBuilder: (context, mode) =>
                      Text(mode == SshAuthMode.password ? '密码' : '私钥'),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => selectedAuthMode = value);
                  },
                ),
              ),
              const SizedBox(height: 15),
              if (selectedAuthMode == SshAuthMode.password)
                Focus(
                  onKeyEvent: (_, event) => handleFieldKey(
                    event,
                    authModeFocusNode,
                    termTypeFocusNode,
                  ),
                  child: DeckTextField(
                    label: '密码',
                    controller: passwordController,
                    hintText: '••••••••',
                    focusNode: passwordFocusNode,
                    obscure: true,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => termTypeFocusNode.requestFocus(),
                  ),
                )
              else
                Focus(
                  onKeyEvent: (_, event) => handleFieldKey(
                    event,
                    authModeFocusNode,
                    termTypeFocusNode,
                  ),
                  child: DeckTextField(
                    label: '私钥路径',
                    controller: privateKeyPathController,
                    hintText: '~/.ssh/id_ed25519',
                    focusNode: privateKeyPathFocusNode,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => termTypeFocusNode.requestFocus(),
                    validator: requiredText,
                  ),
                ),
              const SizedBox(height: 15),
              DeckSelect<String>(
                label: '终端类型',
                value: selectedTermType,
                focusNode: termTypeFocusNode,
                items: SshProfileItem.termTypeOptions,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedTermType = value);
                },
              ),
              const SizedBox(height: 15),
              Text(
                selectedAuthMode == SshAuthMode.password
                    ? '凭据保存在本机配置文件中，不会随配置同步到其他设备。'
                    : '私钥路径只保存在本机，不会随配置同步到其他设备。',
                style: const TextStyle(fontSize: 11, color: DeckTokens.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
