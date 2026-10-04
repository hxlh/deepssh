import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/models/tunnel_config_item.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/deck_widgets.dart';

class TunnelConfigFormPage extends StatefulWidget {
  const TunnelConfigFormPage({
    super.key,
    required this.profiles,
    this.tunnel,
    required this.onCancel,
    required this.onSaved,
  });

  final List<SshProfileItem> profiles;
  final TunnelConfigItem? tunnel;
  final VoidCallback onCancel;
  final ValueChanged<TunnelConfigDraft> onSaved;

  @override
  State<TunnelConfigFormPage> createState() => _TunnelConfigFormPageState();
}

class TunnelConfigDraft {
  const TunnelConfigDraft({
    required this.name,
    required this.type,
    required this.sshProfileId,
    required this.listenHost,
    required this.listenPort,
    required this.targetHost,
    required this.targetPort,
  });

  final String name;
  final TunnelForwardType type;
  final String sshProfileId;
  final String listenHost;
  final int listenPort;
  final String targetHost;
  final int targetPort;
}

class _TunnelConfigFormPageState extends State<TunnelConfigFormPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController listenHostController;
  late final TextEditingController listenPortController;
  late final TextEditingController targetHostController;
  late final TextEditingController targetPortController;
  final nameFocusNode = FocusNode(debugLabel: 'Name');
  final typeFocusNode = FocusNode(debugLabel: 'Type');
  final profileFocusNode = FocusNode(debugLabel: 'SSH Profile');
  final listenHostFocusNode = FocusNode(debugLabel: 'Listen Host');
  final listenPortFocusNode = FocusNode(debugLabel: 'Listen Port');
  final targetHostFocusNode = FocusNode(debugLabel: 'Target Host');
  final targetPortFocusNode = FocusNode(debugLabel: 'Target Port');
  late TunnelForwardType selectedType;
  late String? selectedProfileId;

  @override
  void initState() {
    super.initState();
    final tunnel = widget.tunnel;
    nameController = TextEditingController(text: tunnel?.name ?? '');
    listenHostController = TextEditingController(
      text: tunnel?.listenHost ?? '127.0.0.1',
    );
    listenPortController = TextEditingController(
      text: (tunnel == null || tunnel.listenPort == 0)
          ? ''
          : tunnel.listenPort.toString(),
    );
    targetHostController = TextEditingController(
      text: tunnel?.targetHost ?? '127.0.0.1',
    );
    targetPortController = TextEditingController(
      text: tunnel?.targetPort.toString() ?? '',
    );
    selectedType = tunnel?.type ?? TunnelForwardType.local;
    selectedProfileId =
        tunnel?.sshProfileId ??
        (widget.profiles.isEmpty ? null : widget.profiles.first.id);
  }

  @override
  void dispose() {
    nameController.dispose();
    listenHostController.dispose();
    listenPortController.dispose();
    targetHostController.dispose();
    targetPortController.dispose();
    nameFocusNode.dispose();
    typeFocusNode.dispose();
    profileFocusNode.dispose();
    listenHostFocusNode.dispose();
    listenPortFocusNode.dispose();
    targetHostFocusNode.dispose();
    targetPortFocusNode.dispose();
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

  String? validatePort(String? value, {bool allowAuto = false}) {
    if (allowAuto && (value == null || value.trim().isEmpty)) {
      return null;
    }
    final requiredError = requiredText(value);
    if (requiredError != null) return requiredError;
    final port = int.tryParse(value!.trim());
    if (port == null || port < (allowAuto ? 0 : 1) || port > 65535) {
      return '端口无效';
    }
    return null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    final profileId = selectedProfileId;
    if (profileId == null) return;
    final listenPortText = listenPortController.text.trim();
    widget.onSaved(
      TunnelConfigDraft(
        name: nameController.text.trim(),
        type: selectedType,
        sshProfileId: profileId,
        listenHost: listenHostController.text.trim(),
        listenPort: listenPortText.isEmpty ? 0 : int.parse(listenPortText),
        targetHost: targetHostController.text.trim(),
        targetPort: int.parse(targetPortController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.tunnel != null;
    final canSave = selectedProfileId != null;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DeckEyebrow('Port Forwarding'),
                        DeckTitle(isEdit ? '编辑转发' : '新增转发', size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '监听端口填 0 表示由系统自动分配可用端口。',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
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
              if (widget.profiles.isEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: DeckTokens.dangerSoft,
                    border: const Border(
                      left: BorderSide(color: DeckTokens.danger, width: 3),
                    ),
                  ),
                  child: const Text(
                    '请先创建一个 SSH 配置，再新增转发。',
                    style: TextStyle(fontSize: 12, color: DeckTokens.danger),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Focus(
                onKeyEvent: (_, event) =>
                    handleFieldKey(event, null, typeFocusNode),
                child: TextFormField(
                  focusNode: nameFocusNode,
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => typeFocusNode.requestFocus(),
                  validator: requiredText,
                ),
              ),
              const SizedBox(height: 6),
              Focus(
                onKeyEvent: (_, event) =>
                    handleFieldKey(event, nameFocusNode, profileFocusNode),
                child: DropdownButtonFormField<TunnelForwardType>(
                  focusNode: typeFocusNode,
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: '转发类型'),
                  items: const [
                    DropdownMenuItem(
                      value: TunnelForwardType.local,
                      child: Text('本地转发（-L）'),
                    ),
                    DropdownMenuItem(
                      value: TunnelForwardType.remote,
                      child: Text('远程转发（-R）'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      selectedType = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 6),
              Focus(
                onKeyEvent: (_, event) =>
                    handleFieldKey(event, typeFocusNode, listenHostFocusNode),
                child: DropdownButtonFormField<String>(
                  focusNode: profileFocusNode,
                  initialValue: selectedProfileId,
                  decoration: const InputDecoration(labelText: 'SSH 配置'),
                  items: [
                    for (final profile in widget.profiles)
                      DropdownMenuItem(
                        value: profile.id,
                        child: Text(profile.name),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedProfileId = value;
                    });
                  },
                  validator: (_) =>
                      selectedProfileId == null ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 6),
              Focus(
                onKeyEvent: (_, event) => handleFieldKey(
                  event,
                  profileFocusNode,
                  listenPortFocusNode,
                ),
                child: TextFormField(
                  focusNode: listenHostFocusNode,
                  controller: listenHostController,
                  decoration: const InputDecoration(labelText: '监听主机'),
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => listenPortFocusNode.requestFocus(),
                  validator: requiredText,
                ),
              ),
              const SizedBox(height: 6),
              Focus(
                onKeyEvent: (_, event) => handleFieldKey(
                  event,
                  listenHostFocusNode,
                  targetHostFocusNode,
                ),
                child: TextFormField(
                  focusNode: listenPortFocusNode,
                  controller: listenPortController,
                  decoration: const InputDecoration(labelText: '监听端口'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => targetHostFocusNode.requestFocus(),
                  validator: (value) => validatePort(value, allowAuto: true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 12, bottom: 2),
                child: Text(
                  'Listen port 0 or empty = auto-assign a free local port',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 6),
              Focus(
                onKeyEvent: (_, event) => handleFieldKey(
                  event,
                  listenPortFocusNode,
                  targetPortFocusNode,
                ),
                child: TextFormField(
                  focusNode: targetHostFocusNode,
                  controller: targetHostController,
                  decoration: const InputDecoration(labelText: '目标主机'),
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => targetPortFocusNode.requestFocus(),
                  validator: requiredText,
                ),
              ),
              const SizedBox(height: 6),
              Focus(
                onKeyEvent: (_, event) =>
                    handleFieldKey(event, targetHostFocusNode, null),
                child: TextFormField(
                  focusNode: targetPortFocusNode,
                  controller: targetPortController,
                  decoration: const InputDecoration(labelText: '目标端口'),
                  keyboardType: TextInputType.number,
                  validator: validatePort,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DeckButton(label: '取消', onPressed: widget.onCancel),
                  const SizedBox(width: 8),
                  DeckButton(
                    label: isEdit ? '保存' : '创建',
                    style: DeckButtonStyle.solid,
                    onPressed: canSave ? save : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
