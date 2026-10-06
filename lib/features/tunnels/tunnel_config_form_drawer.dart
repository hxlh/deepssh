import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/models/tunnel_config_item.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/deck_drawer.dart';
import '../../core/widgets/deck_fields.dart';
import '../../core/widgets/deck_widgets.dart';

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

/// Port-forwarding form, drawn as the prototype's right-hand drawer.
///
/// The forwarding list stays mounted behind the scrim so cancelling returns to
/// the list the form was opened from.
class TunnelConfigFormDrawer extends StatefulWidget {
  const TunnelConfigFormDrawer({
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
  State<TunnelConfigFormDrawer> createState() => _TunnelConfigFormDrawerState();
}

class _TunnelConfigFormDrawerState extends State<TunnelConfigFormDrawer> {
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

  /// [allowAuto] lets the listen port stay empty, which the backend reads as
  /// "pick a free port" — the prototype's 监听端口填 0 hint.
  String? validatePort(String? value, {bool allowAuto = false}) {
    if (allowAuto && (value == null || value.trim().isEmpty)) return null;
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
    return DeckDrawer(
      kicker: 'Port Forwarding',
      title: isEdit ? '编辑端口转发' : '新增端口转发',
      onClose: widget.onCancel,
      footer: Row(
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
      child: DeckDrawerBody(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.profiles.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    border: const Border(
                      left: BorderSide(color: DeckTokens.danger, width: 3),
                    ),
                  ),
                  child: const Text(
                    '请先创建一个 SSH 配置，再新增转发。',
                    style: TextStyle(fontSize: 12, color: DeckTokens.danger),
                  ),
                ),
                const SizedBox(height: 15),
              ],
              Focus(
                onKeyEvent: (_, event) =>
                    handleFieldKey(event, null, typeFocusNode),
                child: DeckTextField(
                  label: '名称',
                  controller: nameController,
                  hintText: '例如 web-8080',
                  focusNode: nameFocusNode,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => typeFocusNode.requestFocus(),
                  validator: requiredText,
                ),
              ),
              const SizedBox(height: 15),
              DeckSelect<TunnelForwardType>(
                label: '转发类型',
                value: selectedType,
                focusNode: typeFocusNode,
                items: const [
                  TunnelForwardType.local,
                  TunnelForwardType.remote,
                ],
                itemBuilder: (context, type) => Text(
                  type == TunnelForwardType.local ? '本地转发（-L）' : '远程转发（-R）',
                ),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedType = value);
                },
              ),
              const SizedBox(height: 15),
              DeckSelect<String>(
                label: 'SSH 配置',
                value: selectedProfileId ?? '',
                focusNode: profileFocusNode,
                items: [for (final p in widget.profiles) p.id],
                itemBuilder: (context, id) {
                  final profile = widget.profiles
                      .where((p) => p.id == id)
                      .firstOrNull;
                  return Text(profile?.name ?? id);
                },
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedProfileId = value);
                },
              ),
              const SizedBox(height: 15),
              DeckFieldRow(
                children: [
                  DeckTextField(
                    label: '监听主机',
                    controller: listenHostController,
                    hintText: '127.0.0.1',
                    focusNode: listenHostFocusNode,
                    validator: requiredText,
                  ),
                  DeckTextField(
                    label: '监听端口',
                    controller: listenPortController,
                    focusNode: listenPortFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [digitsOnly()],
                    validator: (value) => validatePort(value, allowAuto: true),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              DeckFieldRow(
                children: [
                  DeckTextField(
                    label: '目标主机',
                    controller: targetHostController,
                    hintText: '10.24.8.11',
                    focusNode: targetHostFocusNode,
                    validator: requiredText,
                  ),
                  DeckTextField(
                    label: '目标端口',
                    controller: targetPortController,
                    hintText: '80',
                    focusNode: targetPortFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [digitsOnly()],
                    validator: (value) => validatePort(value),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                '监听端口填 0 表示由系统自动分配可用端口。',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
