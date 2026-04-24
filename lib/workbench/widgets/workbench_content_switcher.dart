import 'package:flutter/material.dart';

import '../../core/models/ssh_profile_item.dart';
import '../../features/ssh_profiles/ssh_profiles_page.dart';
import '../../features/terminal/terminal_tab_shell.dart';
import '../../features/terminal/terminal_state.dart';

enum WorkbenchContentMode { terminal, sshProfiles }

class WorkbenchContentSwitcher extends StatelessWidget {
  const WorkbenchContentSwitcher({
    super.key,
    required this.mode,
    required this.terminalState,
    required this.sshProfiles,
    required this.onSelectTab,
    required this.onCloseTab,
  });

  final WorkbenchContentMode mode;
  final TerminalState terminalState;
  final List<SshProfileItem> sshProfiles;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<String> onCloseTab;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case WorkbenchContentMode.sshProfiles:
        return SshProfilesPage(profiles: sshProfiles);
      case WorkbenchContentMode.terminal:
        return TerminalTabShell(
          state: terminalState,
          onSelectTab: onSelectTab,
          onCloseTab: onCloseTab,
        );
    }
  }
}
