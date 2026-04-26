import 'package:flutter/material.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/models/theme_settings.dart';
import '../../features/ssh/ssh_bridge.dart';
import '../../features/ssh_profiles/ssh_profile_form_page.dart';
import '../../features/ssh_profiles/ssh_profiles_page.dart';
import '../../features/terminal/terminal_tab_shell.dart';
import '../../features/terminal/terminal_state.dart';
import '../../features/theme_config/theme_config_page.dart';

enum WorkbenchContentMode { terminal, sshProfiles, sshProfileForm, themeConfig }

class WorkbenchContentSwitcher extends StatelessWidget {
  const WorkbenchContentSwitcher({
    super.key,
    required this.mode,
    required this.terminalState,
    required this.sshProfiles,
    required this.sshErrorMessage,
    required this.editingSshProfile,
    required this.uiThemeSettings,
    required this.terminalThemeSettings,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onAddSshProfile,
    required this.onConnectSshProfile,
    required this.onEditSshProfile,
    required this.onDeleteSshProfile,
    required this.onCancelSshForm,
    required this.onSaveSshProfile,
    required this.onUiThemeChanged,
    required this.onTerminalThemeChanged,
    required this.onBackFromConfig,
    required this.sshBridge,
    this.onSshInput,
  });

  final WorkbenchContentMode mode;
  final TerminalState terminalState;
  final List<SshProfileItem> sshProfiles;
  final String? sshErrorMessage;
  final SshProfileItem? editingSshProfile;
  final UiThemeSettings uiThemeSettings;
  final TerminalThemeSettings terminalThemeSettings;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<String> onCloseTab;
  final SshBridgeClient sshBridge;
  final VoidCallback onAddSshProfile;
  final ValueChanged<SshProfileItem> onConnectSshProfile;
  final ValueChanged<SshProfileItem> onEditSshProfile;
  final ValueChanged<SshProfileItem> onDeleteSshProfile;
  final VoidCallback onCancelSshForm;
  final ValueChanged<SshProfileDraft> onSaveSshProfile;
  final ValueChanged<UiThemeSettings> onUiThemeChanged;
  final ValueChanged<TerminalThemeSettings> onTerminalThemeChanged;
  final VoidCallback onBackFromConfig;
  final ValueChanged<String>? onSshInput;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case WorkbenchContentMode.sshProfiles:
        return SshProfilesPage(
          profiles: sshProfiles,
          errorMessage: sshErrorMessage,
          onAdd: onAddSshProfile,
          onConnect: onConnectSshProfile,
          onEdit: onEditSshProfile,
          onDelete: onDeleteSshProfile,
        );
      case WorkbenchContentMode.sshProfileForm:
        return SshProfileFormPage(
          profile: editingSshProfile,
          onCancel: onCancelSshForm,
          onSaved: onSaveSshProfile,
        );
      case WorkbenchContentMode.terminal:
        return TerminalTabShell(
          state: terminalState,
          onSelectTab: onSelectTab,
          onCloseTab: onCloseTab,
          sshBridge: sshBridge,
          terminalThemeSettings: terminalThemeSettings,
          onSshInput: onSshInput,
        );
      case WorkbenchContentMode.themeConfig:
        return ThemeConfigPage(
          uiSettings: uiThemeSettings,
          terminalSettings: terminalThemeSettings,
          onUiSettingsChanged: onUiThemeChanged,
          onTerminalSettingsChanged: onTerminalThemeChanged,
          onBack: onBackFromConfig,
        );
    }
  }
}
