import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/models/tunnel_config_item.dart';

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
      text: tunnel?.listenPort.toString() ?? '',
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
    final profileId = selectedProfileId;
    if (profileId == null) return;
    widget.onSaved(
      TunnelConfigDraft(
        name: nameController.text.trim(),
        type: selectedType,
        sshProfileId: profileId,
        listenHost: listenHostController.text.trim(),
        listenPort: int.parse(listenPortController.text.trim()),
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
              Text(
                isEdit ? 'Edit Tunnel Connection' : 'New Tunnel Connection',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Create local or remote SSH port forwarding.'),
              if (widget.profiles.isEmpty) ...[
                const SizedBox(height: 6),
                const Text(
                  'Create an SSH profile before adding a tunnel.',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 8),
              Focus(
                onKeyEvent: (_, event) =>
                    handleFieldKey(event, null, typeFocusNode),
                child: TextFormField(
                  focusNode: nameFocusNode,
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
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
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: TunnelForwardType.local,
                      child: Text('Local Forward'),
                    ),
                    DropdownMenuItem(
                      value: TunnelForwardType.remote,
                      child: Text('Remote Forward'),
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
                  value: selectedProfileId,
                  decoration: const InputDecoration(labelText: 'SSH Profile'),
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
                  decoration: const InputDecoration(labelText: 'Listen Host'),
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
                  decoration: const InputDecoration(labelText: 'Listen Port'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => targetHostFocusNode.requestFocus(),
                  validator: validatePort,
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
                  decoration: const InputDecoration(labelText: 'Target Host'),
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
                  decoration: const InputDecoration(labelText: 'Target Port'),
                  keyboardType: TextInputType.number,
                  validator: validatePort,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: canSave ? save : null,
                    child: Text(isEdit ? 'Update' : 'Create'),
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
