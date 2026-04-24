import 'package:flutter/material.dart';

import '../core/models/local_terminal_item.dart';
import '../core/models/ssh_profile_item.dart';
import '../core/models/terminal_item.dart';
import '../core/theme/app_colors.dart';
import '../features/hosts/host_tree.dart';
import '../features/hosts/host_tree_state.dart';
import '../features/terminal/terminal_state.dart';
import 'widgets/add_connection_button.dart';
import 'widgets/sidebar.dart';
import 'widgets/workbench_content_switcher.dart';

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({super.key});

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  HostTreeState hostTreeState = HostTreeState();
  TerminalState terminalState = const TerminalState();
  WorkbenchContentMode contentMode = WorkbenchContentMode.terminal;
  int localTerminalCounter = 0;
  bool localExpanded = true;
  List<LocalTerminalItem> localTerminals = const [];

  final List<SshProfileItem> sshProfiles = const [
    SshProfileItem(
      id: 'ssh-prod-bastion',
      name: 'Production Bastion',
      host: 'bastion.example.com',
      username: 'ubuntu',
    ),
    SshProfileItem(
      id: 'ssh-staging-api',
      name: 'Staging API',
      host: 'staging-api.internal',
      username: 'deploy',
    ),
  ];

  void _handleHostToggle(String hostId) {
    setState(() {
      hostTreeState = hostTreeState.toggleHost(hostId);
    });
  }

  void _handleTerminalTap(TerminalItem terminal) {
    final host = hostTreeState.hosts.firstWhere((item) => item.id == terminal.hostId);
    final tab = OpenTerminalTab.fromItems(host, terminal);

    setState(() {
      terminalState = terminalState.open(tab);
      contentMode = WorkbenchContentMode.terminal;
    });
  }

  void _handleLocalToggle() {
    setState(() {
      localExpanded = !localExpanded;
    });
  }

  void _handleLocalTerminalTap(LocalTerminalItem terminal) {
    final tab = OpenTerminalTab.local(id: terminal.id, title: terminal.title);
    setState(() {
      terminalState = terminalState.open(tab);
      contentMode = WorkbenchContentMode.terminal;
    });
  }

  void _handleTabSelect(String tabId) {
    setState(() {
      terminalState = terminalState.activate(tabId);
      contentMode = WorkbenchContentMode.terminal;
    });
  }

  void _handleTabClose(String tabId) {
    setState(() {
      terminalState = terminalState.close(tabId);
    });
  }

  void _createLocalTerminal() {
    final nextIndex = localTerminalCounter + 1;
    final terminal = LocalTerminalItem(
      id: 'local-terminal-$nextIndex',
      title: 'terminal$nextIndex',
    );
    final tab = OpenTerminalTab.local(id: terminal.id, title: terminal.title);

    setState(() {
      localTerminalCounter = nextIndex;
      localExpanded = true;
      localTerminals = [...localTerminals, terminal];
      terminalState = terminalState.open(tab);
      contentMode = WorkbenchContentMode.terminal;
    });
  }

  void _handleAddConnection(AddConnectionAction action) {
    switch (action) {
      case AddConnectionAction.localTerminal:
        _createLocalTerminal();
        break;
      case AddConnectionAction.ssh:
        setState(() {
          contentMode = WorkbenchContentMode.sshProfiles;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            onAddConnectionSelected: _handleAddConnection,
            child: HostTree(
              state: hostTreeState,
              selectedTerminalId: terminalState.activeTabId,
              onToggleHost: _handleHostToggle,
              onTerminalTap: _handleTerminalTap,
              localTerminals: localTerminals,
              localExpanded: localExpanded,
              onToggleLocal: _handleLocalToggle,
              onLocalTerminalTap: _handleLocalTerminalTap,
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: WorkbenchContentSwitcher(
              mode: contentMode,
              terminalState: terminalState,
              sshProfiles: sshProfiles,
              onSelectTab: _handleTabSelect,
              onCloseTab: _handleTabClose,
            ),
          ),
        ],
      ),
    );
  }
}
