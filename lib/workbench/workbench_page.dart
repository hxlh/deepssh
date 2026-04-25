import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../core/models/local_terminal_item.dart';
import '../core/models/ssh_profile_item.dart';
import '../core/models/ssh_session_item.dart';
import '../core/models/terminal_item.dart';
import '../core/theme/app_colors.dart';
import '../features/hosts/host_tree.dart';
import '../features/hosts/host_tree_state.dart';
import '../features/ssh/ssh_bridge.dart';
import '../features/ssh_profiles/ssh_profile_form_page.dart';
import '../features/terminal/terminal_state.dart';
import 'widgets/add_connection_button.dart';
import 'widgets/sidebar.dart';
import 'widgets/workbench_content_switcher.dart';

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({super.key, SshBridgeClient? sshBridge})
    : sshBridge = sshBridge ?? const _DefaultSshBridgeClientHolder();

  final SshBridgeClient sshBridge;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _DefaultSshBridgeClientHolder implements SshBridgeClient {
  const _DefaultSshBridgeClientHolder();

  static final InMemorySshBridgeClient _delegate = InMemorySshBridgeClient();

  @override
  Future<List<SshProfileItem>> listProfiles() => _delegate.listProfiles();

  @override
  Future<SshProfileItem> createProfile({
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
  }) => _delegate.createProfile(
    name: name,
    host: host,
    port: port,
    username: username,
    password: password,
  );

  @override
  Future<SshProfileItem> updateProfile({
    required String id,
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
  }) => _delegate.updateProfile(
    id: id,
    name: name,
    host: host,
    port: port,
    username: username,
    password: password,
  );

  @override
  Future<void> deleteProfile(String id) => _delegate.deleteProfile(id);

  @override
  Future<SshConnectionResult> connectProfile(String id) =>
      _delegate.connectProfile(id);

  @override
  Stream<List<int>> outputStream(String sessionId) =>
      _delegate.outputStream(sessionId);

  @override
  Future<void> writeToSession(String sessionId, List<int> data) =>
      _delegate.writeToSession(sessionId, data);

  @override
  Future<void> resizeSession({
    required String sessionId,
    required int rows,
    required int cols,
  }) => _delegate.resizeSession(sessionId: sessionId, rows: rows, cols: cols);

  @override
  Future<void> closeSession(String sessionId) =>
      _delegate.closeSession(sessionId);
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  static const int sshSessionHistoryLineLimit = 3000;

  HostTreeState hostTreeState = HostTreeState();
  TerminalState terminalState = const TerminalState();
  WorkbenchContentMode contentMode = WorkbenchContentMode.terminal;
  int localTerminalCounter = 0;
  bool localExpanded = true;
  List<LocalTerminalItem> localTerminals = const [];
  List<SshProfileItem> sshProfiles = const [];
  Map<String, List<SshSessionItem>> sshSessionsByProfileId = const {};
  int sshSessionCounter = 0;
  final sshOutputSubscriptions = <String, StreamSubscription<String>>{};
  final closingSshSessionIds = <String>{};
  final removedPendingSshSessionIds = <String>{};
  SshProfileItem? editingSshProfile;
  String? sshErrorMessage;

  @override
  void initState() {
    super.initState();
    loadSshProfiles();
  }

  @override
  void dispose() {
    for (final subscription in sshOutputSubscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> loadSshProfiles() async {
    final profiles = await widget.sshBridge.listProfiles();
    if (!mounted) return;
    setState(() {
      sshProfiles = profiles;
    });
  }

  void _handleHostToggle(String hostId) {
    setState(() {
      hostTreeState = hostTreeState.toggleHost(hostId);
    });
  }

  void _handleTerminalTap(TerminalItem terminal) {
    final host = hostTreeState.hosts.firstWhere(
      (item) => item.id == terminal.hostId,
    );
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

  Future<void> _handleCloseLocalTerminal(LocalTerminalItem terminal) async {
    setState(() {
      localTerminals = [
        for (final item in localTerminals)
          if (item.id != terminal.id) item,
      ];
      terminalState = terminalState.close(terminal.id);
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
          editingSshProfile = null;
          sshErrorMessage = null;
        });
        loadSshProfiles();
        break;
    }
  }

  void _handleAddSshProfile() {
    setState(() {
      editingSshProfile = null;
      contentMode = WorkbenchContentMode.sshProfileForm;
    });
  }

  void _handleEditSshProfile(SshProfileItem profile) {
    setState(() {
      editingSshProfile = profile;
      contentMode = WorkbenchContentMode.sshProfileForm;
    });
  }

  Future<void> _handleSaveSshProfile(SshProfileDraft draft) async {
    final editing = editingSshProfile;
    if (editing == null) {
      await widget.sshBridge.createProfile(
        name: draft.name,
        host: draft.host,
        port: draft.port,
        username: draft.username,
        password: draft.password,
      );
    } else {
      await widget.sshBridge.updateProfile(
        id: editing.id,
        name: draft.name,
        host: draft.host,
        port: draft.port,
        username: draft.username,
        password: draft.password,
      );
    }
    await loadSshProfiles();
    if (!mounted) return;
    setState(() {
      editingSshProfile = null;
      contentMode = WorkbenchContentMode.sshProfiles;
    });
  }

  Future<void> _handleDeleteSshProfile(SshProfileItem profile) async {
    await widget.sshBridge.deleteProfile(profile.id);
    await loadSshProfiles();
  }

  OpenTerminalTab _sshTabFromSession(SshSessionItem session) {
    return OpenTerminalTab.ssh(
      id: session.id,
      hostName: session.hostName,
      title: session.title,
      sessionId: session.sessionId,
      history: session.history,
      terminal: session.terminal,
    );
  }

  void _handleSshSessionTap(SshSessionItem session) {
    setState(() {
      terminalState = terminalState.open(_sshTabFromSession(session));
      contentMode = WorkbenchContentMode.terminal;
    });
  }

  String _appendSshHistory(String history, String text) {
    final lines = '$history$text'.split('\n');
    if (lines.length <= sshSessionHistoryLineLimit) {
      return '$history$text';
    }
    return lines.skip(lines.length - sshSessionHistoryLineLimit).join('\n');
  }

  void _startSshOutputSubscription(SshSessionItem session) {
    final sessionId = session.sessionId;
    if (sessionId == null || sshOutputSubscriptions.containsKey(session.id)) {
      return;
    }
    sshOutputSubscriptions[session.id] = widget.sshBridge
        .outputStream(sessionId)
        .transform(utf8.decoder)
        .listen(
          (text) {
            if (!mounted || text.isEmpty) return;
            final sessions =
                sshSessionsByProfileId[session.profileId] ??
                const <SshSessionItem>[];
            SshSessionItem? updatedSession;
            final nextSessions = [
              for (final item in sessions)
                if (item.id == session.id)
                  updatedSession = item.copyWith(
                    history: _appendSshHistory(item.history, text),
                  )
                else
                  item,
            ];
            if (updatedSession == null) return;
            final terminal = updatedSession.terminal;
            if (terminal != null) {
              terminal.write(text);
            }
            setState(() {
              sshSessionsByProfileId = {
                ...sshSessionsByProfileId,
                session.profileId: nextSessions,
              };
              terminalState = terminalState.update(
                _sshTabFromSession(updatedSession!),
              );
            });
          },
          onDone: () {
            sshOutputSubscriptions.remove(session.id);
          },
        );
  }

  void _updateSshSession(SshSessionItem session) {
    final sessions =
        sshSessionsByProfileId[session.profileId] ?? const <SshSessionItem>[];
    setState(() {
      sshSessionsByProfileId = {
        ...sshSessionsByProfileId,
        session.profileId: [
          for (final item in sessions) item.id == session.id ? session : item,
        ],
      };
      terminalState = terminalState.update(_sshTabFromSession(session));
    });
    _startSshOutputSubscription(session);
  }

  void _removeSshSession(SshSessionItem session) {
    final sessions =
        sshSessionsByProfileId[session.profileId] ?? const <SshSessionItem>[];
    final nextSessions = sessions
        .where((item) => item.id != session.id)
        .toList();
    setState(() {
      sshSessionsByProfileId = {
        ...sshSessionsByProfileId,
        session.profileId: nextSessions,
      };
      terminalState = terminalState.close(session.id);
    });
  }

  Future<void> _handleCloseSshSession(SshSessionItem session) async {
    if (!closingSshSessionIds.add(session.id)) {
      return;
    }

    final sessionId = session.sessionId;
    if (sessionId == null) {
      removedPendingSshSessionIds.add(session.id);
      _removeSshSession(session);
      closingSshSessionIds.remove(session.id);
      return;
    }

    try {
      await widget.sshBridge.closeSession(sessionId);
    } catch (error) {
      closingSshSessionIds.remove(session.id);
      if (!mounted) return;
      setState(() {
        sshErrorMessage = 'Close session failed: $error';
      });
      return;
    }

    try {
      await sshOutputSubscriptions.remove(session.id)?.cancel();
    } catch (_) {}

    closingSshSessionIds.remove(session.id);
    if (!mounted) return;
    _removeSshSession(session);
  }

  Future<void> _handleConnectSshProfile(SshProfileItem profile) async {
    final nextIndex = sshSessionCounter + 1;
    final session = SshSessionItem(
      id: 'ssh-pending-$nextIndex',
      profileId: profile.id,
      hostName: profile.host,
      title: 'terminal$nextIndex',
      terminal: xterm.Terminal(maxLines: sshSessionHistoryLineLimit),
    );
    final sessions =
        sshSessionsByProfileId[profile.id] ?? const <SshSessionItem>[];

    setState(() {
      sshSessionCounter = nextIndex;
      sshSessionsByProfileId = {
        ...sshSessionsByProfileId,
        profile.id: [...sessions, session],
      };
      terminalState = terminalState.open(_sshTabFromSession(session));
      contentMode = WorkbenchContentMode.terminal;
      sshErrorMessage = null;
    });

    try {
      final result = await widget.sshBridge.connectProfile(profile.id);
      if (!mounted) return;
      if (removedPendingSshSessionIds.remove(session.id)) {
        try {
          await widget.sshBridge.closeSession(result.sessionId);
        } catch (error) {
          if (!mounted) return;
          setState(() {
            sshErrorMessage = 'Close pending session failed: $error';
          });
        }
        return;
      }
      _updateSshSession(session.copyWith(sessionId: result.sessionId));
    } catch (error) {
      if (!mounted) return;
      _removeSshSession(session);
      setState(() {
        sshErrorMessage = 'Connection failed: $error';
        contentMode = WorkbenchContentMode.sshProfiles;
      });
    }
  }

  void _handleCancelSshForm() {
    setState(() {
      editingSshProfile = null;
      contentMode = WorkbenchContentMode.sshProfiles;
    });
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
              sshProfiles: sshProfiles,
              sshSessionsByProfileId: sshSessionsByProfileId,
              onSshProfileTap: (_) {},
              onSshSessionTap: _handleSshSessionTap,
              onCloseSshSession: _handleCloseSshSession,
              onCloseLocalTerminal: _handleCloseLocalTerminal,
            ),
          ),
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.border,
          ),
          Expanded(
            child: WorkbenchContentSwitcher(
              mode: contentMode,
              terminalState: terminalState,
              sshProfiles: sshProfiles,
              sshErrorMessage: sshErrorMessage,
              editingSshProfile: editingSshProfile,
              onSelectTab: _handleTabSelect,
              onCloseTab: _handleTabClose,
              onAddSshProfile: _handleAddSshProfile,
              onConnectSshProfile: _handleConnectSshProfile,
              onEditSshProfile: _handleEditSshProfile,
              onDeleteSshProfile: _handleDeleteSshProfile,
              onCancelSshForm: _handleCancelSshForm,
              onSaveSshProfile: _handleSaveSshProfile,
              sshBridge: widget.sshBridge,
            ),
          ),
        ],
      ),
    );
  }
}
