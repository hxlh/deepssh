import 'package:flutter/material.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../core/models/theme_settings.dart';
import '../../core/models/tunnel_config_item.dart';
import '../../features/local_terminal/local_terminal_bridge.dart';
import '../../features/ssh/ssh_bridge.dart';
import '../../features/diagnostics/diagnostics_page.dart';
import '../../features/ssh_profiles/ssh_profile_form_page.dart';
import '../../features/ssh_profiles/ssh_profiles_page.dart';
import '../../features/terminal/terminal_tab_shell.dart';
import '../../features/terminal/terminal_view.dart';
import '../../features/tunnels/tunnel_config_form_page.dart';
import '../../features/tunnels/tunnel_configs_page.dart';
import '../../features/terminal/terminal_state.dart';
import '../../features/theme_config/theme_config_page.dart';

enum WorkbenchContentMode {
  terminal,
  sshProfiles,
  sshProfileForm,
  tunnelConfigs,
  tunnelConfigForm,
  themeConfig,
  diagnostics,
}

class WorkbenchContentSwitcher extends StatelessWidget {
  const WorkbenchContentSwitcher({
    super.key,
    required this.mode,
    required this.terminalState,
    required this.sshProfiles,
    required this.sshErrorMessage,
    required this.editingSshProfile,
    required this.tunnelConfigs,
    required this.tunnelErrorMessage,
    required this.editingTunnelConfig,
    required this.uiThemeSettings,
    required this.terminalThemeSettings,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onReorderTab,
    required this.onAddSshProfile,
    required this.onConnectSshProfile,
    required this.onEditSshProfile,
    required this.onDeleteSshProfile,
    required this.onCancelSshForm,
    required this.onSaveSshProfile,
    required this.onAddTunnelConfig,
    required this.onStartTunnelConfig,
    required this.onStopTunnelConfig,
    required this.onEditTunnelConfig,
    required this.onDeleteTunnelConfig,
    required this.onCancelTunnelForm,
    required this.onSaveTunnelConfig,
    required this.onUiThemeChanged,
    required this.onTerminalThemeChanged,
    required this.onBackFromConfig,
    required this.sshBridge,
    required this.localTerminalBridge,
    this.onSshInput,
    this.onSshTerminalInput,
    this.onPreviewLabelChanged,
  });

  final WorkbenchContentMode mode;
  final TerminalState terminalState;
  final List<SshProfileItem> sshProfiles;
  final String? sshErrorMessage;
  final SshProfileItem? editingSshProfile;
  final List<TunnelConfigItem> tunnelConfigs;
  final String? tunnelErrorMessage;
  final TunnelConfigItem? editingTunnelConfig;
  final UiThemeSettings uiThemeSettings;
  final TerminalThemeSettings terminalThemeSettings;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<String> onCloseTab;
  final void Function(int oldIndex, int newIndex) onReorderTab;
  final SshBridgeClient sshBridge;
  final LocalTerminalBridgeClient localTerminalBridge;
  final VoidCallback onAddSshProfile;
  final ValueChanged<SshProfileItem> onConnectSshProfile;
  final ValueChanged<SshProfileItem> onEditSshProfile;
  final ValueChanged<SshProfileItem> onDeleteSshProfile;
  final VoidCallback onCancelSshForm;
  final ValueChanged<SshProfileDraft> onSaveSshProfile;
  final VoidCallback onAddTunnelConfig;
  final ValueChanged<TunnelConfigItem> onStartTunnelConfig;
  final ValueChanged<TunnelConfigItem> onStopTunnelConfig;
  final ValueChanged<TunnelConfigItem> onEditTunnelConfig;
  final ValueChanged<TunnelConfigItem> onDeleteTunnelConfig;
  final VoidCallback onCancelTunnelForm;
  final ValueChanged<TunnelConfigDraft> onSaveTunnelConfig;
  final ValueChanged<UiThemeSettings> onUiThemeChanged;
  final ValueChanged<TerminalThemeSettings> onTerminalThemeChanged;
  final VoidCallback onBackFromConfig;
  final ValueChanged<String>? onSshInput;
  final SshTerminalInputWriter? onSshTerminalInput;
  final ValueChanged<String>? onPreviewLabelChanged;

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
      case WorkbenchContentMode.tunnelConfigs:
        return TunnelConfigsPage(
          tunnels: tunnelConfigs,
          profiles: sshProfiles,
          errorMessage: tunnelErrorMessage,
          onAdd: onAddTunnelConfig,
          onStart: onStartTunnelConfig,
          onStop: onStopTunnelConfig,
          onEdit: onEditTunnelConfig,
          onDelete: onDeleteTunnelConfig,
        );
      case WorkbenchContentMode.tunnelConfigForm:
        return TunnelConfigFormPage(
          profiles: sshProfiles,
          tunnel: editingTunnelConfig,
          onCancel: onCancelTunnelForm,
          onSaved: onSaveTunnelConfig,
        );
      case WorkbenchContentMode.terminal:
        return TerminalTabShell(
          state: terminalState,
          onSelectTab: onSelectTab,
          onCloseTab: onCloseTab,
          onReorderTab: onReorderTab,
          sshBridge: sshBridge,
          localTerminalBridge: localTerminalBridge,
          terminalThemeSettings: terminalThemeSettings,
          onSshInput: onSshInput,
          onSshTerminalInput: onSshTerminalInput,
          onPreviewLabelChanged: onPreviewLabelChanged,
        );
      case WorkbenchContentMode.themeConfig:
        return ThemeConfigPage(
          uiSettings: uiThemeSettings,
          terminalSettings: terminalThemeSettings,
          onUiSettingsChanged: onUiThemeChanged,
          onTerminalSettingsChanged: onTerminalThemeChanged,
          onBack: onBackFromConfig,
        );
      case WorkbenchContentMode.diagnostics:
        return DiagnosticsPage(onBack: onBackFromConfig);
    }
  }
}
