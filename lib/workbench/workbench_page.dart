import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../core/logging/app_logger.dart';
import '../core/models/local_terminal_item.dart';
import '../core/models/ssh_profile_item.dart';
import '../core/models/ssh_session_item.dart';
import '../core/models/terminal_item.dart';
import '../core/models/theme_settings.dart';
import '../core/theme/app_colors.dart';
import '../features/hosts/host_tree.dart';
import '../features/hosts/host_tree_state.dart';
import '../features/ssh/ssh_bridge.dart';
import '../features/ssh_profiles/ssh_profile_form_page.dart';
import '../features/terminal/terminal_state.dart';
import '../features/theme/theme_bridge.dart';
import 'widgets/add_connection_button.dart';
import 'widgets/sidebar.dart';
import 'widgets/workbench_content_switcher.dart';

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({
    super.key,
    SshBridgeClient? sshBridge,
    ThemeBridgeClient? themeBridge,
    this.onThemeChanged,
    this.errorLogger,
  }) : sshBridge = sshBridge ?? const _DefaultSshBridgeClientHolder(),
       themeBridge = themeBridge ?? const _DefaultThemeBridgeClientHolder();

  final SshBridgeClient sshBridge;
  final ThemeBridgeClient themeBridge;
  final VoidCallback? onThemeChanged;
  final ErrorLogger? errorLogger;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _SshSessionNoteDialog extends StatefulWidget {
  const _SshSessionNoteDialog({required this.initialNote});

  final String initialNote;

  @override
  State<_SshSessionNoteDialog> createState() => _SshSessionNoteDialogState();
}

class _SshSessionNoteDialogState extends State<_SshSessionNoteDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑备注'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: '会话备注'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
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
    required String termType,
  }) => _delegate.createProfile(
    name: name,
    host: host,
    port: port,
    username: username,
    password: password,
    termType: termType,
  );

  @override
  Future<SshProfileItem> updateProfile({
    required String id,
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    required String termType,
  }) => _delegate.updateProfile(
    id: id,
    name: name,
    host: host,
    port: port,
    username: username,
    password: password,
    termType: termType,
  );

  @override
  Future<void> deleteProfile(String id) => _delegate.deleteProfile(id);

  @override
  Future<SshConnectionResult> connectProfile(
    String id, {
    int? rows,
    int? cols,
  }) => _delegate.connectProfile(id, rows: rows, cols: cols);

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

  @override
  Future<SshConnectionResult> duplicateSession(String sessionId) =>
      _delegate.duplicateSession(sessionId);
}

class _DefaultThemeBridgeClientHolder implements ThemeBridgeClient {
  const _DefaultThemeBridgeClientHolder();

  static final InMemoryThemeBridgeClient _delegate =
      InMemoryThemeBridgeClient();

  @override
  Future<({UiThemeSettings ui, TerminalThemeSettings terminal})> loadTheme() =>
      _delegate.loadTheme();

  @override
  Future<void> saveTheme({
    required UiThemeSettings ui,
    required TerminalThemeSettings terminal,
  }) => _delegate.saveTheme(ui: ui, terminal: terminal);
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
  final sshOutputBuffers = <String, StringBuffer>{};
  final sshOutputFlushTimers = <String, Timer>{};
  final closingSshSessionIds = <String>{};
  final removedPendingSshSessionIds = <String>{};
  final _sshCommandBuffers = <String, String>{};
  SshProfileItem? editingSshProfile;
  String? sshErrorMessage;
  UiThemeSettings uiThemeSettings = UiThemeSettings.commandDeck();
  TerminalThemeSettings terminalThemeSettings =
      TerminalThemeSettings.commandDeck();
  bool _themeSaveInFlight = false;
  bool _themeSaveQueued = false;

  ErrorLogger get _errorLogger =>
      widget.errorLogger ?? FileErrorLogger.frontend();

  @override
  void initState() {
    super.initState();
    loadSshProfiles();
    loadInitialTheme();
  }

  @override
  void dispose() {
    for (final timer in sshOutputFlushTimers.values) {
      timer.cancel();
    }
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

  Future<void> loadInitialTheme() async {
    try {
      final loaded = await widget.themeBridge.loadTheme();
      if (!mounted) return;
      AppColors.applyUi(loaded.ui);
      AppColors.applyTerminal(loaded.terminal);
      setState(() {
        uiThemeSettings = loaded.ui;
        terminalThemeSettings = loaded.terminal;
      });
      widget.onThemeChanged?.call();
    } catch (error, stackTrace) {
      unawaited(_errorLogger.error('theme.load', error, stackTrace));
      // Keep built-in defaults if persistence is unavailable.
    }
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

  void _handleTabReorder(int oldIndex, int newIndex) {
    setState(() {
      terminalState = terminalState.reorder(oldIndex, newIndex);
    });
  }

  void _handleReorderProfiles(int oldIndex, int newIndex) {
    setState(() {
      final next = [...sshProfiles];
      final item = next.removeAt(oldIndex);
      final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
      next.insert(insertAt, item);
      sshProfiles = next;
    });
  }

  void _handleReorderSessions(String profileId, int oldIndex, int newIndex) {
    setState(() {
      final sessions = [...?sshSessionsByProfileId[profileId]];
      final item = sessions.removeAt(oldIndex);
      final sInsertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
      sessions.insert(sInsertAt, item);
      sshSessionsByProfileId = {...sshSessionsByProfileId, profileId: sessions};
    });
  }

  void _handleReorderLocalTerminals(int oldIndex, int newIndex) {
    setState(() {
      final next = [...localTerminals];
      final item = next.removeAt(oldIndex);
      final ltInsertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
      next.insert(ltInsertAt, item);
      localTerminals = next;
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
        termType: draft.termType,
      );
    } else {
      await widget.sshBridge.updateProfile(
        id: editing.id,
        name: draft.name,
        host: draft.host,
        port: draft.port,
        username: draft.username,
        password: draft.password,
        termType: draft.termType,
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

  void _scheduleSshOutputFlush(SshSessionItem session) {
    if (sshOutputFlushTimers.containsKey(session.id)) return;
    sshOutputFlushTimers[session.id] = Timer(
      const Duration(milliseconds: 16),
      () {
        sshOutputFlushTimers.remove(session.id);
        _flushSshOutput(session);
      },
    );
  }

  void _flushSshOutput(SshSessionItem session) {
    final buffer = sshOutputBuffers.remove(session.id);
    if (buffer == null || !mounted) return;
    final text = buffer.toString();
    if (text.isEmpty) return;

    final sessions =
        sshSessionsByProfileId[session.profileId] ?? const <SshSessionItem>[];
    SshSessionItem? updatedSession;
    final nextSessions = [
      for (final item in sessions)
        if (item.id == session.id)
          updatedSession = item.copyWith(
            history: item.terminal == null
                ? _appendSshHistory(item.history, text)
                : item.history,
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
      terminalState = terminalState.update(_sshTabFromSession(updatedSession!));
    });
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
            final buffer = sshOutputBuffers.putIfAbsent(
              session.id,
              StringBuffer.new,
            );
            buffer.write(text);
            _scheduleSshOutputFlush(session);
          },
          onDone: () {
            sshOutputFlushTimers.remove(session.id)?.cancel();
            _flushSshOutput(session);
            sshOutputSubscriptions.remove(session.id);
          },
        );
  }

  void _replaceSshSession(SshSessionItem session) {
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
  }

  void _updateSshSession(SshSessionItem session) {
    _replaceSshSession(session);
    _startSshOutputSubscription(session);
  }

  void _handleSshInput(String data) {
    final sessionId = terminalState.activeTab?.sessionId;
    if (sessionId == null) return;

    var buffer = _sshCommandBuffers[sessionId] ?? '';

    for (final rune in data.runes) {
      if (rune == 0x0D || rune == 0x0A) {
        _commitSshCommand(sessionId, buffer);
        buffer = '';
        break;
      } else if (rune == 0x7F) {
        if (buffer.isNotEmpty) {
          final runes = buffer.runes.toList();
          runes.removeLast();
          buffer = String.fromCharCodes(runes);
        }
      } else if (rune == 0x03) {
        buffer = '';
        break;
      } else if (rune == 0x1B) {
        break;
      } else if (rune == 0x09) {
        // Ignore tab for command inference.
      } else if (rune >= 0x20) {
        buffer += String.fromCharCode(rune);
      }
    }

    _sshCommandBuffers[sessionId] = buffer;
  }

  void _commitSshCommand(String sessionId, String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;

    for (final sessions in sshSessionsByProfileId.values) {
      for (final session in sessions) {
        if (session.sessionId == sessionId) {
          _replaceSshSession(session.copyWith(currentCommand: trimmed));
          return;
        }
      }
    }
  }

  void _removeSshSession(SshSessionItem session) {
    final sessions =
        sshSessionsByProfileId[session.profileId] ?? const <SshSessionItem>[];
    final nextSessions = sessions
        .where((item) => item.id != session.id)
        .toList();
    sshOutputFlushTimers.remove(session.id)?.cancel();
    sshOutputBuffers.remove(session.id);
    if (session.sessionId != null) {
      _sshCommandBuffers.remove(session.sessionId);
    }
    setState(() {
      sshSessionsByProfileId = {
        ...sshSessionsByProfileId,
        session.profileId: nextSessions,
      };
      terminalState = terminalState.close(session.id);
    });
  }

  Future<void> _handleEditSshSessionNote(SshSessionItem session) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _SshSessionNoteDialog(initialNote: session.note),
    );
    if (note == null || !mounted) return;
    _replaceSshSession(session.copyWith(note: note));
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
    } catch (error, stackTrace) {
      unawaited(_errorLogger.error('ssh.close', error, stackTrace));
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

  Future<void> _handleDuplicateSshSession(SshSessionItem session) async {
    final sessionId = session.sessionId;
    if (sessionId == null) return;

    final nextIndex = sshSessionCounter + 1;
    final newSession = SshSessionItem(
      id: 'ssh-pending-$nextIndex',
      profileId: session.profileId,
      hostName: session.hostName,
      title: 'terminal$nextIndex',
      terminal: xterm.Terminal(maxLines: terminalThemeSettings.scrollbackLines),
    );
    final sessions =
        sshSessionsByProfileId[session.profileId] ?? const <SshSessionItem>[];

    setState(() {
      sshSessionCounter = nextIndex;
      sshSessionsByProfileId = {
        ...sshSessionsByProfileId,
        session.profileId: [...sessions, newSession],
      };
      terminalState = terminalState.open(_sshTabFromSession(newSession));
      contentMode = WorkbenchContentMode.terminal;
    });

    try {
      final result = await widget.sshBridge.duplicateSession(sessionId);
      if (!mounted) return;
      if (removedPendingSshSessionIds.remove(newSession.id)) {
        try {
          await widget.sshBridge.closeSession(result.sessionId);
        } catch (error, stackTrace) {
          unawaited(_errorLogger.error('ssh.close', error, stackTrace));
        }
        return;
      }
      _updateSshSession(newSession.copyWith(sessionId: result.sessionId));
    } catch (error, stackTrace) {
      unawaited(_errorLogger.error('ssh.duplicate', error, stackTrace));
      if (!mounted) return;
      _removeSshSession(newSession);
      setState(() {
        sshErrorMessage = 'Duplicate session failed: $error';
      });
    }
  }

  Future<void> _handleConnectSshProfile(SshProfileItem profile) async {
    final nextIndex = sshSessionCounter + 1;
    final session = SshSessionItem(
      id: 'ssh-pending-$nextIndex',
      profileId: profile.id,
      hostName: profile.host,
      title: 'terminal$nextIndex',
      terminal: xterm.Terminal(maxLines: terminalThemeSettings.scrollbackLines),
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

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      final result = await widget.sshBridge.connectProfile(
        profile.id,
        rows: session.terminal?.viewHeight,
        cols: session.terminal?.viewWidth,
      );
      if (!mounted) return;
      if (removedPendingSshSessionIds.remove(session.id)) {
        try {
          await widget.sshBridge.closeSession(result.sessionId);
        } catch (error, stackTrace) {
          unawaited(_errorLogger.error('ssh.close', error, stackTrace));
          if (!mounted) return;
          setState(() {
            sshErrorMessage = 'Close pending session failed: $error';
          });
        }
        return;
      }
      final currentSessions =
          sshSessionsByProfileId[profile.id] ?? const <SshSessionItem>[];
      SshSessionItem? currentSession;
      for (final item in currentSessions) {
        if (item.id == session.id) {
          currentSession = item;
          break;
        }
      }
      if (currentSession == null) return;
      _updateSshSession(currentSession.copyWith(sessionId: result.sessionId));
    } catch (error, stackTrace) {
      unawaited(_errorLogger.error('ssh.connect', error, stackTrace));
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

  void _handleOpenThemeConfig() {
    setState(() {
      contentMode = WorkbenchContentMode.themeConfig;
    });
  }

  void _handleBackFromConfig() {
    setState(() {
      contentMode = WorkbenchContentMode.terminal;
    });
  }

  void _handleUiThemeChanged(UiThemeSettings settings) {
    AppColors.applyUi(settings);
    setState(() {
      uiThemeSettings = settings;
    });
    widget.onThemeChanged?.call();
    _persistTheme();
  }

  void _handleTerminalThemeChanged(TerminalThemeSettings settings) {
    AppColors.applyTerminal(settings);
    setState(() {
      terminalThemeSettings = settings;
    });
    widget.onThemeChanged?.call();
    _persistTheme();
  }

  Future<void> _persistTheme() async {
    if (_themeSaveInFlight) {
      _themeSaveQueued = true;
      return;
    }

    _themeSaveInFlight = true;
    do {
      _themeSaveQueued = false;
      final ui = uiThemeSettings;
      final terminal = terminalThemeSettings;
      try {
        await widget.themeBridge.saveTheme(ui: ui, terminal: terminal);
      } catch (error, stackTrace) {
        unawaited(_errorLogger.error('theme.save', error, stackTrace));
        // Ignore persistence errors so the UI keeps responding.
      }
    } while (_themeSaveQueued);
    _themeSaveInFlight = false;
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
              onEditSshSessionNote: _handleEditSshSessionNote,
              onCloseSshSession: _handleCloseSshSession,
              onDuplicateSshSession: _handleDuplicateSshSession,
              onCloseLocalTerminal: _handleCloseLocalTerminal,
              onOpenThemeConfig: _handleOpenThemeConfig,
              themeConfigActive:
                  contentMode == WorkbenchContentMode.themeConfig,
              onReorderProfiles: _handleReorderProfiles,
              onReorderSessions: _handleReorderSessions,
              onReorderLocalTerminals: _handleReorderLocalTerminals,
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: WorkbenchContentSwitcher(
              mode: contentMode,
              terminalState: terminalState,
              sshProfiles: sshProfiles,
              sshErrorMessage: sshErrorMessage,
              editingSshProfile: editingSshProfile,
              uiThemeSettings: uiThemeSettings,
              terminalThemeSettings: terminalThemeSettings,
              onSelectTab: _handleTabSelect,
              onCloseTab: _handleTabClose,
              onReorderTab: _handleTabReorder,
              onAddSshProfile: _handleAddSshProfile,
              onConnectSshProfile: _handleConnectSshProfile,
              onEditSshProfile: _handleEditSshProfile,
              onDeleteSshProfile: _handleDeleteSshProfile,
              onCancelSshForm: _handleCancelSshForm,
              onSaveSshProfile: _handleSaveSshProfile,
              onUiThemeChanged: _handleUiThemeChanged,
              onTerminalThemeChanged: _handleTerminalThemeChanged,
              onBackFromConfig: _handleBackFromConfig,
              sshBridge: widget.sshBridge,
              onSshInput: _handleSshInput,
            ),
          ),
        ],
      ),
    );
  }
}
