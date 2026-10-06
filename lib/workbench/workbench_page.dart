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
import '../core/models/tunnel_config_item.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/deck_fields.dart';
import '../core/widgets/deck_toast.dart';
import '../core/widgets/deck_widgets.dart';
import '../features/hosts/host_tree.dart';
import '../features/hosts/host_tree_state.dart';
import '../features/local_terminal/local_terminal_bridge.dart';
import '../features/ssh/ssh_bridge.dart';
import '../features/ssh/ssh_zmodem_file_picker.dart';
import '../features/ssh/ssh_zmodem_session.dart';
import '../src/rust/mem_metrics.dart';
import '../features/ssh_profiles/ssh_profile_form_drawer.dart';
import '../features/terminal/terminal_state.dart';
import '../features/terminal/terminal_view.dart';
import '../features/theme/theme_bridge.dart';
import '../features/tunnels/tunnel_bridge.dart';
import '../features/tunnels/tunnel_config_form_drawer.dart';
import '../src/rust/ssh_auth.dart' as rust_auth;
import 'events/workbench_events.dart';
import 'widgets/add_connection_button.dart';
import 'widgets/app_topbar.dart';
import 'widgets/resize_handle.dart';
import 'widgets/sidebar.dart';
import 'widgets/workbench_content_switcher.dart';
import 'widgets/workbench_dock.dart';

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({
    super.key,
    SshBridgeClient? sshBridge,
    LocalTerminalBridgeClient? localTerminalBridge,
    TunnelBridgeClient? tunnelBridge,
    ThemeBridgeClient? themeBridge,
    this.onThemeChanged,
    this.errorLogger,
    this.debugSshInputWriter,
    this.debugSshZModemFactory,
  }) : sshBridge = sshBridge ?? const _DefaultSshBridgeClientHolder(),
       localTerminalBridge =
           localTerminalBridge ??
           const _DefaultLocalTerminalBridgeClientHolder(),
       tunnelBridge = tunnelBridge ?? const _DefaultTunnelBridgeClientHolder(),
       themeBridge = themeBridge ?? const _DefaultThemeBridgeClientHolder();

  final SshBridgeClient sshBridge;
  final LocalTerminalBridgeClient localTerminalBridge;
  final TunnelBridgeClient tunnelBridge;
  final ThemeBridgeClient themeBridge;
  final VoidCallback? onThemeChanged;
  final ErrorLogger? errorLogger;
  final SshTerminalInputWriter? debugSshInputWriter;
  final SshZModemBindingFactory? debugSshZModemFactory;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _SecretPromptDialog extends StatefulWidget {
  const _SecretPromptDialog({required this.title, required this.label});

  final String title;
  final String label;

  @override
  State<_SecretPromptDialog> createState() => _SecretPromptDialogState();
}

class _SecretPromptDialogState extends State<_SecretPromptDialog> {
  late final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DeckDialog(
      title: widget.title,
      actions: [
        DeckButton(label: '取消', onPressed: () => Navigator.of(context).pop()),
        DeckButton(
          label: '连接',
          style: DeckButtonStyle.accent,
          onPressed: () => Navigator.of(context).pop(controller.text),
        ),
      ],
      child: DeckTextField(
        label: widget.label,
        controller: controller,
        obscure: true,
        autocorrect: false,
        enableSuggestions: false,
      ),
    );
  }
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
    return DeckDialog(
      title: '编辑备注',
      actions: [
        DeckButton(label: '取消', onPressed: () => Navigator.of(context).pop()),
        DeckButton(
          label: '保存',
          style: DeckButtonStyle.accent,
          onPressed: () => Navigator.of(context).pop(controller.text),
        ),
      ],
      child: DeckTextField(
        label: '会话备注',
        controller: controller,
        hintText: '例如 发布流水线',
        autocorrect: false,
      ),
    );
  }
}

class _DefaultTunnelBridgeClientHolder implements TunnelBridgeClient {
  const _DefaultTunnelBridgeClientHolder();

  static final RustTunnelBridgeClient _delegate = RustTunnelBridgeClient();

  @override
  Future<List<TunnelConfigItem>> listTunnels() => _delegate.listTunnels();

  @override
  Future<TunnelConfigItem> createTunnel({
    required String name,
    required TunnelForwardType type,
    required String sshProfileId,
    required String listenHost,
    required int listenPort,
    required String targetHost,
    required int targetPort,
  }) => _delegate.createTunnel(
    name: name,
    type: type,
    sshProfileId: sshProfileId,
    listenHost: listenHost,
    listenPort: listenPort,
    targetHost: targetHost,
    targetPort: targetPort,
  );

  @override
  Future<TunnelConfigItem> updateTunnel({
    required String id,
    required String name,
    required TunnelForwardType type,
    required String sshProfileId,
    required String listenHost,
    required int listenPort,
    required String targetHost,
    required int targetPort,
  }) => _delegate.updateTunnel(
    id: id,
    name: name,
    type: type,
    sshProfileId: sshProfileId,
    listenHost: listenHost,
    listenPort: listenPort,
    targetHost: targetHost,
    targetPort: targetPort,
  );

  @override
  Future<void> deleteTunnel(String id) => _delegate.deleteTunnel(id);

  @override
  Future<TunnelConfigItem> startTunnel(
    String id, {
    required SshProfileItem sshProfile,
    String? password,
    String? passphrase,
  }) => _delegate.startTunnel(
    id,
    sshProfile: sshProfile,
    password: password,
    passphrase: passphrase,
  );

  @override
  Future<TunnelConfigItem> stopTunnel(String id) => _delegate.stopTunnel(id);
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
    required SshAuthMode authMode,
    required String password,
    required String privateKeyPath,
    required String termType,
  }) => _delegate.createProfile(
    name: name,
    host: host,
    port: port,
    username: username,
    authMode: authMode,
    password: password,
    privateKeyPath: privateKeyPath,
    termType: termType,
  );

  @override
  Future<SshProfileItem> updateProfile({
    required String id,
    required String name,
    required String host,
    required int port,
    required String username,
    required SshAuthMode authMode,
    required String password,
    required String privateKeyPath,
    required String termType,
  }) => _delegate.updateProfile(
    id: id,
    name: name,
    host: host,
    port: port,
    username: username,
    authMode: authMode,
    password: password,
    privateKeyPath: privateKeyPath,
    termType: termType,
  );

  @override
  Future<void> deleteProfile(String id) => _delegate.deleteProfile(id);

  @override
  Future<SshConnectionResult> connectProfile(
    String id, {
    String? password,
    String? passphrase,
    int? rows,
    int? cols,
  }) => _delegate.connectProfile(
    id,
    password: password,
    passphrase: passphrase,
    rows: rows,
    cols: cols,
  );

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

class _DefaultLocalTerminalBridgeClientHolder
    implements LocalTerminalBridgeClient {
  const _DefaultLocalTerminalBridgeClientHolder();

  static final RustLocalTerminalBridgeClient _delegate =
      RustLocalTerminalBridgeClient();

  @override
  Future<LocalTerminalConnectionResult> spawnLocalTerminal({
    int? rows,
    int? cols,
  }) => _delegate.spawnLocalTerminal(rows: rows, cols: cols);

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
  // Force an immediate flush when the per-session output buffer crosses this
  // size, instead of waiting for the 16ms debounce timer. Stops bursty
  // producers (e.g. `rg` over SSH dumping match output) from piling several
  // MiB into one StringBuffer before the next frame fires.
  static const int outputFlushSizeLimit = 32 * 1024;

  HostTreeState hostTreeState = HostTreeState();
  TerminalState terminalState = const TerminalState();
  WorkbenchContentMode contentMode = WorkbenchContentMode.terminal;

  final WorkbenchEvents _events = WorkbenchEvents();

  double _dockHeight = 280;
  bool _dockCollapsed = false;

  /// Topbar run summary sources.
  DateTime? _clock;
  Timer? _clockTimer;
  Timer? _memoryTimer;
  double? _memoryRssMb;

  /// Whether the dock's 内存监控 panel is in the row. The Explorer's footer
  /// button owns this, matching the prototype's `exMemToggle`.
  bool _memoryDockVisible = true;

  /// Last successful connect per SSH profile, shown in the connections list.
  /// Kept in memory only — the prototype treats it as a display value.
  final Map<String, DateTime> _lastConnectedAt = <String, DateTime>{};
  int localTerminalCounter = 0;
  bool localExpanded = true;
  List<LocalTerminalItem> localTerminals = const [];
  List<SshProfileItem> sshProfiles = const [];
  List<String> explorerSectionOrder = const [];
  Map<String, List<SshSessionItem>> sshSessionsByProfileId = const {};
  int sshSessionCounter = 0;
  final sshZModemSessions = <String, SshZModemBinding>{};
  final sshOutputBuffers = <String, StringBuffer>{};
  final sshOutputFlushTimers = <String, Timer>{};
  final closingSshSessionIds = <String>{};
  final removedPendingSshSessionIds = <String>{};
  final localOutputSubscriptions = <String, StreamSubscription<String>>{};
  final localOutputBuffers = <String, StringBuffer>{};
  final localOutputFlushTimers = <String, Timer>{};
  final closingLocalTerminalIds = <String>{};
  final removedPendingLocalTerminalIds = <String>{};
  // _sshCommandBuffers removed — see _handleSshInput comment below.
  SshProfileItem? editingSshProfile;
  String? sshErrorMessage;
  List<TunnelConfigItem> tunnelConfigs = const [];
  TunnelConfigItem? editingTunnelConfig;
  String? tunnelErrorMessage;
  Timer? tunnelStatusRefreshTimer;
  UiThemeSettings uiThemeSettings = UiThemeSettings.commandDeck();
  TerminalThemeSettings terminalThemeSettings =
      TerminalThemeSettings.commandDeck();
  bool _themeSaveInFlight = false;
  bool _themeSaveQueued = false;
  // 56px is the prototype's icon-rail width; below the compact breakpoint the
  // Explorer sheds its labels and keeps icons only.
  static const double _minSidebarWidth = 56;
  double _sidebarWidth = AppSpacing.sidebarWidth;

  /// True while the Explorer splitter is under the pointer. The terminal
  /// listens (through [ExplorerResizeHold]) and holds its width for the
  /// duration so a drag does not reflow the whole scrollback every frame.
  final ValueNotifier<bool> _explorerResizeHold = ValueNotifier<bool>(false);

  ErrorLogger get _errorLogger =>
      widget.errorLogger ?? FileErrorLogger.frontend();

  @override
  void initState() {
    super.initState();
    loadSshProfiles();
    loadTunnelConfigs();
    loadInitialTheme();
    _clock = DateTime.now();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() => _clock = DateTime.now()),
    );
    unawaited(_refreshTopbarMemory());
    _memoryTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshTopbarMemory(),
    );
  }

  /// Samples RSS for the topbar run summary.
  ///
  /// Mirrors the dock's rule: a failed sample or an unchanged reading leaves
  /// state alone, so widget tests (no Rust) schedule no frames.
  Future<void> _refreshTopbarMemory() async {
    late final RustMemSnapshot next;
    try {
      next = await rustMemSnapshot();
    } catch (_) {
      return;
    }
    final mb = next.currentRss.toDouble() / (1024 * 1024);
    if (!mounted || _memoryRssMb == mb) return;
    setState(() => _memoryRssMb = mb);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _memoryTimer?.cancel();
    tunnelStatusRefreshTimer?.cancel();
    for (final timer in sshOutputFlushTimers.values) {
      timer.cancel();
    }
    for (final timer in localOutputFlushTimers.values) {
      timer.cancel();
    }
    for (final binding in sshZModemSessions.values) {
      unawaited(binding.dispose());
    }
    for (final subscription in localOutputSubscriptions.values) {
      subscription.cancel();
    }
    _explorerResizeHold.dispose();
    super.dispose();
  }

  Future<void> loadSshProfiles() async {
    final profiles = await widget.sshBridge.listProfiles();
    if (!mounted) return;
    setState(() {
      sshProfiles = profiles;
    });
  }

  Future<void> loadTunnelConfigs() async {
    try {
      final tunnels = await widget.tunnelBridge.listTunnels();
      if (!mounted) return;
      setState(() {
        tunnelConfigs = tunnels;
      });
      _syncTunnelStatusRefresh(tunnels);
    } catch (error, stackTrace) {
      unawaited(_errorLogger.error('tunnel.list', error, stackTrace));
      if (!mounted) return;
      setState(() {
        tunnelErrorMessage = 'Load tunnels failed: $error';
      });
    }
  }

  void _syncTunnelStatusRefresh(List<TunnelConfigItem> tunnels) {
    final needsRefresh = tunnels.any((tunnel) => tunnel.isRunning);
    if (!needsRefresh) {
      tunnelStatusRefreshTimer?.cancel();
      tunnelStatusRefreshTimer = null;
      return;
    }
    tunnelStatusRefreshTimer ??= Timer.periodic(const Duration(seconds: 2), (
      _,
    ) {
      if (mounted) {
        unawaited(loadTunnelConfigs());
      }
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

  OpenTerminalTab _localTabFromTerminal(LocalTerminalItem terminal) {
    return OpenTerminalTab.local(
      id: terminal.id,
      title: terminal.title,
      displayLabel: terminal.displayTitle,
      sessionId: terminal.sessionId,
      terminal: terminal.terminal,
    );
  }

  void _showLocalTerminalError(String message) {
    showDeckToast(context, message);
  }

  void _replaceLocalTerminal(LocalTerminalItem terminal) {
    setState(() {
      localTerminals = [
        for (final item in localTerminals)
          item.id == terminal.id ? terminal : item,
      ];
      terminalState = terminalState.update(_localTabFromTerminal(terminal));
    });
  }

  void _removeLocalTerminal(LocalTerminalItem terminal) {
    localOutputFlushTimers.remove(terminal.id)?.cancel();
    localOutputBuffers.remove(terminal.id);
    setState(() {
      localTerminals = [
        for (final item in localTerminals)
          if (item.id != terminal.id) item,
      ];
      terminalState = terminalState.close(terminal.id);
    });
    _collectIdleResourcesIfDrained();
  }

  // Releases Flutter-side caches when the user has closed every terminal and
  // SSH session. Pairs with the Rust `collect_idle_pages_if_drained` hook —
  // mimalloc handles the native heap, this clears the image/raster cache that
  // Skia keeps until evicted.
  void _collectIdleResourcesIfDrained() {
    final hasSshSessions = sshSessionsByProfileId.values.any(
      (sessions) => sessions.isNotEmpty,
    );
    if (hasSshSessions || localTerminals.isNotEmpty) return;
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  void _scheduleLocalOutputFlush(LocalTerminalItem terminal) {
    if (localOutputFlushTimers.containsKey(terminal.id)) return;
    localOutputFlushTimers[terminal.id] = Timer(
      const Duration(milliseconds: 16),
      () {
        localOutputFlushTimers.remove(terminal.id);
        _flushLocalOutput(terminal);
      },
    );
  }

  void _flushLocalOutput(LocalTerminalItem terminal) {
    final buffer = localOutputBuffers.remove(terminal.id);
    if (buffer == null || !mounted) return;
    final text = buffer.toString();
    if (text.isEmpty) return;

    LocalTerminalItem? currentTerminal;
    for (final item in localTerminals) {
      if (item.id == terminal.id) {
        currentTerminal = item;
        break;
      }
    }
    if (currentTerminal == null) return;

    // Write directly to the xterm Terminal object. Same reasoning as
    // _flushSshOutput: the terminal drives its own repaint, so setState()
    // here would rebuild the entire WorkbenchPage tree every 16 ms for free.
    currentTerminal.terminal?.write(text);
  }

  void _startLocalOutputSubscription(LocalTerminalItem terminal) {
    final sessionId = terminal.sessionId;
    if (sessionId == null ||
        localOutputSubscriptions.containsKey(terminal.id)) {
      return;
    }
    localOutputSubscriptions[terminal.id] = widget.localTerminalBridge
        .outputStream(sessionId)
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          (text) {
            if (!mounted || text.isEmpty) return;
            final buffer = localOutputBuffers.putIfAbsent(
              terminal.id,
              StringBuffer.new,
            );
            buffer.write(text);
            if (buffer.length >= outputFlushSizeLimit) {
              localOutputFlushTimers.remove(terminal.id)?.cancel();
              _flushLocalOutput(terminal);
            } else {
              _scheduleLocalOutputFlush(terminal);
            }
          },
          onDone: () {
            localOutputFlushTimers.remove(terminal.id)?.cancel();
            _flushLocalOutput(terminal);
            localOutputSubscriptions.remove(terminal.id);
          },
        );
  }

  void _handleLocalTerminalTap(LocalTerminalItem terminal) {
    setState(() {
      terminalState = terminalState.open(_localTabFromTerminal(terminal));
      contentMode = WorkbenchContentMode.terminal;
    });
  }

  Future<void> _handleCloseLocalTerminal(LocalTerminalItem terminal) async {
    if (!closingLocalTerminalIds.add(terminal.id)) {
      return;
    }

    final sessionId = terminal.sessionId;
    if (sessionId == null) {
      removedPendingLocalTerminalIds.add(terminal.id);
      _removeLocalTerminal(terminal);
      closingLocalTerminalIds.remove(terminal.id);
      return;
    }

    try {
      await widget.localTerminalBridge.closeSession(sessionId);
    } catch (error, stackTrace) {
      unawaited(_errorLogger.error('local_terminal.close', error, stackTrace));
      closingLocalTerminalIds.remove(terminal.id);
      if (!mounted) return;
      _showLocalTerminalError('Close local terminal failed: $error');
      return;
    }

    try {
      await localOutputSubscriptions.remove(terminal.id)?.cancel();
    } catch (_) {}

    closingLocalTerminalIds.remove(terminal.id);
    if (!mounted) return;
    _removeLocalTerminal(terminal);
  }

  void _handleTabSelect(String tabId) {
    setState(() {
      terminalState = terminalState.activate(tabId);
      contentMode = WorkbenchContentMode.terminal;
    });
  }

  void _handleActiveTabPreviewLabelChanged(String previewLabel) {
    final activeTab = terminalState.activeTab;
    if (activeTab == null) return;

    switch (activeTab.sourceType) {
      case TerminalSourceType.local:
        for (final terminal in localTerminals) {
          if (terminal.id == activeTab.id) {
            if (terminal.previewLabel == previewLabel) return;
            _replaceLocalTerminal(
              terminal.copyWith(previewLabel: previewLabel),
            );
            return;
          }
        }
        return;
      case TerminalSourceType.ssh:
        for (final sessions in sshSessionsByProfileId.values) {
          for (final session in sessions) {
            if (session.id == activeTab.id) {
              if (session.previewLabel == previewLabel) return;
              _replaceSshSession(session.copyWith(previewLabel: previewLabel));
              return;
            }
          }
        }
        return;
      case TerminalSourceType.remote:
        return;
    }
  }

  void _handleTabClose(String tabId) {
    for (final terminal in localTerminals) {
      if (terminal.id == tabId) {
        // Close the tab UI only; keep the underlying terminal process alive
        // so the user can reopen it from the host tree.
        setState(() {
          terminalState = terminalState.close(tabId);
        });
        return;
      }
    }
    setState(() {
      terminalState = terminalState.close(tabId);
    });
  }

  void _handleTabReorder(int oldIndex, int newIndex) {
    setState(() {
      terminalState = terminalState.reorder(oldIndex, newIndex);
    });
  }

  void _handleExplorerSectionOrderChanged(List<String> next) {
    setState(() {
      explorerSectionOrder = next;
      final profilesById = {
        for (final profile in sshProfiles) profile.id: profile,
      };
      sshProfiles = [
        for (final id in next)
          if (id.startsWith('profile:') &&
              profilesById[id.substring('profile:'.length)] != null)
            profilesById[id.substring('profile:'.length)]!,
      ];
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

  Future<void> _createLocalTerminal() async {
    final nextIndex = localTerminalCounter + 1;
    final terminal = LocalTerminalItem(
      id: 'local-terminal-$nextIndex',
      title: 'terminal$nextIndex',
      terminal: xterm.Terminal(maxLines: terminalThemeSettings.scrollbackLines),
    );

    setState(() {
      localTerminalCounter = nextIndex;
      localExpanded = true;
      localTerminals = [...localTerminals, terminal];
      terminalState = terminalState.open(_localTabFromTerminal(terminal));
      contentMode = WorkbenchContentMode.terminal;
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      final result = await widget.localTerminalBridge.spawnLocalTerminal(
        rows: terminal.terminal?.viewHeight,
        cols: terminal.terminal?.viewWidth,
      );
      if (!mounted) return;
      if (removedPendingLocalTerminalIds.remove(terminal.id)) {
        await widget.localTerminalBridge.closeSession(result.sessionId);
        return;
      }
      final currentTerminal = localTerminals.firstWhere(
        (item) => item.id == terminal.id,
      );
      final updatedTerminal = currentTerminal.copyWith(
        sessionId: result.sessionId,
      );
      _replaceLocalTerminal(updatedTerminal);
      _startLocalOutputSubscription(updatedTerminal);
    } catch (error, stackTrace) {
      unawaited(_errorLogger.error('local_terminal.spawn', error, stackTrace));
      if (!mounted) return;
      _removeLocalTerminal(terminal);
      _showLocalTerminalError('Local terminal failed: $error');
    }
  }

  void _handleAddConnection(AddConnectionAction action) {
    switch (action) {
      case AddConnectionAction.localTerminal:
        unawaited(_createLocalTerminal());
        break;
      case AddConnectionAction.ssh:
        setState(() {
          contentMode = WorkbenchContentMode.sshProfiles;
          editingSshProfile = null;
          sshErrorMessage = null;
        });
        loadSshProfiles();
        break;
      case AddConnectionAction.tunnel:
        setState(() {
          contentMode = WorkbenchContentMode.tunnelConfigs;
          editingTunnelConfig = null;
          tunnelErrorMessage = null;
        });
        loadSshProfiles();
        loadTunnelConfigs();
        break;
    }
  }

  void _handleAddTunnelConfig() {
    setState(() {
      editingTunnelConfig = null;
      contentMode = WorkbenchContentMode.tunnelConfigForm;
    });
  }

  void _handleEditTunnelConfig(TunnelConfigItem tunnel) {
    setState(() {
      editingTunnelConfig = tunnel;
      contentMode = WorkbenchContentMode.tunnelConfigForm;
    });
  }

  void _handleCancelTunnelForm() {
    setState(() {
      editingTunnelConfig = null;
      contentMode = WorkbenchContentMode.tunnelConfigs;
    });
  }

  Future<void> _handleSaveTunnelConfig(TunnelConfigDraft draft) async {
    try {
      final editing = editingTunnelConfig;
      if (editing == null) {
        await widget.tunnelBridge.createTunnel(
          name: draft.name,
          type: draft.type,
          sshProfileId: draft.sshProfileId,
          listenHost: draft.listenHost,
          listenPort: draft.listenPort,
          targetHost: draft.targetHost,
          targetPort: draft.targetPort,
        );
      } else {
        await widget.tunnelBridge.updateTunnel(
          id: editing.id,
          name: draft.name,
          type: draft.type,
          sshProfileId: draft.sshProfileId,
          listenHost: draft.listenHost,
          listenPort: draft.listenPort,
          targetHost: draft.targetHost,
          targetPort: draft.targetPort,
        );
      }
      await loadTunnelConfigs();
      if (!mounted) return;
      setState(() {
        editingTunnelConfig = null;
        contentMode = WorkbenchContentMode.tunnelConfigs;
        tunnelErrorMessage = null;
      });
    } catch (error, stackTrace) {
      unawaited(_errorLogger.error('tunnel.save', error, stackTrace));
      if (!mounted) return;
      setState(() {
        tunnelErrorMessage = 'Save tunnel failed: $error';
        contentMode = WorkbenchContentMode.tunnelConfigs;
      });
    }
  }

  Future<void> _handleDeleteTunnelConfig(TunnelConfigItem tunnel) async {
    try {
      await widget.tunnelBridge.deleteTunnel(tunnel.id);
      await loadTunnelConfigs();
    } catch (error, stackTrace) {
      unawaited(_errorLogger.error('tunnel.delete', error, stackTrace));
      if (!mounted) return;
      setState(() {
        tunnelErrorMessage = 'Delete tunnel failed: $error';
      });
    }
  }

  Future<void> _handleStartTunnelConfig(TunnelConfigItem tunnel) async {
    try {
      final profile = sshProfiles.firstWhere(
        (profile) => profile.id == tunnel.sshProfileId,
      );
      String? runtimePassword;
      if (profile.authMode == SshAuthMode.password &&
          profile.password.isEmpty) {
        runtimePassword = await _promptSecret(
          title: 'SSH Password',
          label: 'Password',
        );
        if (runtimePassword == null || !mounted) return;
      }

      Future<TunnelConfigItem> start({String? passphrase}) {
        return widget.tunnelBridge.startTunnel(
          tunnel.id,
          sshProfile: profile,
          password: runtimePassword,
          passphrase: passphrase,
        );
      }

      TunnelConfigItem started;
      try {
        started = await start();
      } on SshConnectException catch (error) {
        if (profile.authMode != SshAuthMode.privateKey ||
            error.code != rust_auth.SshConnectErrorCode.passphraseRequired) {
          rethrow;
        }
        final passphrase = await _promptSecret(
          title: 'Private Key Passphrase',
          label: 'Passphrase',
        );
        if (passphrase == null || !mounted) return;
        started = await start(passphrase: passphrase);
      }
      _events.record(
        WorkbenchEventLevel.info,
        '转发已启动',
        subject:
            '${started.listenHost}:${started.listenPortLabel} → ${started.targetHost}:${started.targetPort}',
      );
      _replaceTunnelConfig(started);
      _syncTunnelStatusRefresh([
        for (final item in tunnelConfigs)
          item.id == started.id ? started : item,
      ]);
    } catch (error, stackTrace) {
      unawaited(_errorLogger.error('tunnel.start', error, stackTrace));
      if (!mounted) return;
      setState(() {
        tunnelErrorMessage = 'Start tunnel failed: $error';
      });
    }
  }

  Future<void> _handleStopTunnelConfig(TunnelConfigItem tunnel) async {
    try {
      final stopped = await widget.tunnelBridge.stopTunnel(tunnel.id);
      _events.record(WorkbenchEventLevel.info, '转发已停止', subject: tunnel.name);
      _replaceTunnelConfig(stopped);
      await loadTunnelConfigs();
    } catch (error, stackTrace) {
      unawaited(_errorLogger.error('tunnel.stop', error, stackTrace));
      if (!mounted) return;
      setState(() {
        tunnelErrorMessage = 'Stop tunnel failed: $error';
      });
    }
  }

  void _replaceTunnelConfig(TunnelConfigItem tunnel) {
    if (!mounted) return;
    setState(() {
      tunnelConfigs = [
        for (final item in tunnelConfigs) item.id == tunnel.id ? tunnel : item,
      ];
      tunnelErrorMessage = null;
    });
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
        authMode: draft.authMode,
        password: draft.password,
        privateKeyPath: draft.privateKeyPath,
        termType: draft.termType,
      );
    } else {
      await widget.sshBridge.updateProfile(
        id: editing.id,
        name: draft.name,
        host: draft.host,
        port: draft.port,
        username: draft.username,
        authMode: draft.authMode,
        password: draft.password,
        privateKeyPath: draft.privateKeyPath,
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
    SshProfileItem? profile;
    for (final item in sshProfiles) {
      if (item.id == session.profileId) {
        profile = item;
        break;
      }
    }
    return OpenTerminalTab.ssh(
      id: session.id,
      hostName: session.hostName,
      title: session.title,
      displayLabel: session.displayTitle,
      sessionId: session.sessionId,
      history: session.history,
      terminal: session.terminal,
      termType: profile?.termType,
    );
  }

  void _handleSshSessionTap(SshSessionItem session) {
    setState(() {
      terminalState = terminalState.open(_sshTabFromSession(session));
      contentMode = WorkbenchContentMode.terminal;
    });
  }

  // Appends [text] to [history], capping at sshSessionHistoryLineLimit lines
  // by trimming from the front. The previous implementation built a full
  // List<String> via split/join on every call — at 60 Hz with rg-style
  // streams that allocated tens of MiB of garbage per second. Now we scan
  // code units once, then either return the bare concat or take a single
  // substring from the cut point.
  String _appendSshHistory(String history, String text) {
    if (text.isEmpty) return history;
    final combined = history + text;
    int newlineCount = 0;
    for (int i = 0; i < combined.length; i++) {
      if (combined.codeUnitAt(i) == 0x0A) newlineCount++;
    }
    if (newlineCount <= sshSessionHistoryLineLimit) {
      return combined;
    }
    int toDrop = newlineCount - sshSessionHistoryLineLimit;
    int cut = 0;
    for (int i = 0; i < combined.length; i++) {
      if (combined.codeUnitAt(i) == 0x0A) {
        toDrop--;
        if (toDrop == 0) {
          cut = i + 1;
          break;
        }
      }
    }
    return combined.substring(cut);
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
    SshSessionItem? currentSession;
    final nextSessions = [
      for (final item in sessions)
        if (item.id == session.id)
          currentSession = item.copyWith(
            history: item.terminal == null
                ? _appendSshHistory(item.history, text)
                : item.history,
          )
        else
          item,
    ];
    if (currentSession == null) return;
    final terminal = currentSession.terminal;
    if (terminal != null) {
      // Write directly to the xterm Terminal object. It notifies its own
      // listeners and drives its own repaint — no setState() needed here.
      // Calling setState() would rebuild the entire WorkbenchPage tree
      // (sidebar + content) every 16 ms for no visible change.
      terminal.write(text);
      return;
    }
    // No live terminal object: persist output in history and update the tab
    // so TerminalView can replay it when the tab is next opened.
    setState(() {
      sshSessionsByProfileId = {
        ...sshSessionsByProfileId,
        session.profileId: nextSessions,
      };
      terminalState = terminalState.update(_sshTabFromSession(currentSession!));
    });
  }

  void _startSshOutputSubscription(SshSessionItem session) {
    final sessionId = session.sessionId;
    if (sessionId == null || sshZModemSessions.containsKey(session.id)) {
      return;
    }

    void writeTerminalText(String text) {
      if (!mounted || text.isEmpty) return;
      final buffer = sshOutputBuffers.putIfAbsent(session.id, StringBuffer.new);
      buffer.write(text);
      if (buffer.length >= outputFlushSizeLimit) {
        sshOutputFlushTimers.remove(session.id)?.cancel();
        _flushSshOutput(session);
      } else {
        _scheduleSshOutputFlush(session);
      }
    }

    void handleDone() {
      sshOutputFlushTimers.remove(session.id)?.cancel();
      _flushSshOutput(session);
      final binding = sshZModemSessions.remove(session.id);
      if (binding != null) {
        unawaited(binding.dispose());
      }
    }

    final factory = widget.debugSshZModemFactory;
    if (factory != null) {
      sshZModemSessions[session.id] = factory(
        sessionId: sessionId,
        stdout: widget.sshBridge.outputStream(sessionId),
        writeTerminal: writeTerminalText,
        onDone: handleDone,
      );
      return;
    }

    final binding = RemoteSshZModemSession(
      sessionId: sessionId,
      stdout: widget.sshBridge.outputStream(sessionId),
      writeToSession: widget.sshBridge.writeToSession,
      writeTerminal: writeTerminalText,
      selectDownloadDirectory: selectZModemDownloadDirectory,
      selectUploadFiles: selectZModemUploadFiles,
      logger: _errorLogger,
      onDone: handleDone,
    );
    binding.start();
    sshZModemSessions[session.id] = binding;
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

  void _writeSshTerminalInput(String sessionId, String data) {
    final debugWriter = widget.debugSshInputWriter;
    if (debugWriter != null) {
      debugWriter(sessionId, data);
      return;
    }

    for (final sessions in sshSessionsByProfileId.values) {
      for (final session in sessions) {
        if (session.sessionId == sessionId) {
          final binding = sshZModemSessions[session.id];
          if (binding != null) {
            binding.writeTerminalInput(data);
            return;
          }
        }
      }
    }

    widget.sshBridge.writeToSession(sessionId, utf8.encode(data));
  }

  // _handleSshInput and _commitSshCommand previously tracked keystrokes to
  // store currentCommand on SshSessionItem, but currentCommand was never read
  // by any widget. Every Enter key triggered _replaceSshSession() -> setState()
  // rebuilding the entire WorkbenchPage tree for nothing. Both methods and the
  // _sshCommandBuffers map have been removed.
  //
  // If command tracking is needed in the future, store it in a plain Map
  // without calling setState(), or use a separate ChangeNotifier scoped to
  // only the widgets that actually display it.

  void _removeSshSession(SshSessionItem session) {
    final sessions =
        sshSessionsByProfileId[session.profileId] ?? const <SshSessionItem>[];
    final nextSessions = sessions
        .where((item) => item.id != session.id)
        .toList();
    sshOutputFlushTimers.remove(session.id)?.cancel();
    sshOutputBuffers.remove(session.id);
    // _sshCommandBuffers.remove removed — field no longer exists.
    final binding = sshZModemSessions.remove(session.id);
    if (binding != null) {
      unawaited(binding.dispose());
    }
    setState(() {
      sshSessionsByProfileId = {
        ...sshSessionsByProfileId,
        session.profileId: nextSessions,
      };
      terminalState = terminalState.close(session.id);
    });
    _collectIdleResourcesIfDrained();
  }

  Future<void> _handleEditSshSessionNote(SshSessionItem session) async {
    final note = await showDialog<String>(
      context: context,
      // Same 42% scrim as the other three deck dialogs (`.overlay`).
      barrierColor: DeckTokens.wash(AppColors.textPrimary, 0.42),
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
        _events.record(WorkbenchEventLevel.warn, '关闭会话失败', subject: '$error');
        sshErrorMessage = 'Close session failed: $error';
      });
      return;
    }

    try {
      await sshZModemSessions.remove(session.id)?.dispose();
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
      connectionGroupId: session.connectionGroupId,
    );
    final sessions =
        sshSessionsByProfileId[session.profileId] ?? const <SshSessionItem>[];
    final sourceIndex = sessions.indexWhere((s) => s.id == session.id);
    final insertIndex = sourceIndex >= 0 ? sourceIndex + 1 : sessions.length;
    final nextSessions = [...sessions];
    nextSessions.insert(insertIndex, newSession);

    setState(() {
      sshSessionCounter = nextIndex;
      sshSessionsByProfileId = {
        ...sshSessionsByProfileId,
        session.profileId: nextSessions,
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

  Future<String?> _promptSecret({
    required String title,
    required String label,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: DeckTokens.wash(AppColors.textPrimary, 0.42),
      builder: (context) => _SecretPromptDialog(title: title, label: label),
    );
  }

  Future<void> _handleConnectSshProfile(SshProfileItem profile) async {
    String? runtimePassword;
    if (profile.authMode == SshAuthMode.password && profile.password.isEmpty) {
      runtimePassword = await _promptSecret(
        title: 'SSH Password',
        label: 'Password',
      );
      if (runtimePassword == null || !mounted) return;
    }

    final nextIndex = sshSessionCounter + 1;
    final connectionGroupId =
        'conn-${DateTime.now().millisecondsSinceEpoch}-$nextIndex';
    final session = SshSessionItem(
      id: 'ssh-pending-$nextIndex',
      profileId: profile.id,
      hostName: profile.host,
      title: 'terminal$nextIndex',
      terminal: xterm.Terminal(maxLines: terminalThemeSettings.scrollbackLines),
      connectionGroupId: connectionGroupId,
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
      Future<SshConnectionResult> connect({String? passphrase}) {
        return widget.sshBridge.connectProfile(
          profile.id,
          password: runtimePassword,
          passphrase: passphrase,
          rows: session.terminal?.viewHeight,
          cols: session.terminal?.viewWidth,
        );
      }

      SshConnectionResult result;
      try {
        result = await connect();
      } on SshConnectException catch (error) {
        if (profile.authMode != SshAuthMode.privateKey ||
            error.code != rust_auth.SshConnectErrorCode.passphraseRequired) {
          rethrow;
        }
        final passphrase = await _promptSecret(
          title: 'Private Key Passphrase',
          label: 'Passphrase',
        );
        if (passphrase == null || !mounted) {
          _removeSshSession(session);
          if (!mounted) return;
          setState(() {
            contentMode = WorkbenchContentMode.sshProfiles;
          });
          return;
        }
        result = await connect(passphrase: passphrase);
      }
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
      _lastConnectedAt[profile.id] = DateTime.now();
      _events.record(
        WorkbenchEventLevel.info,
        '已连接',
        subject: '${profile.username}@${profile.host}:${profile.port}',
      );
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
        _events.record(
          WorkbenchEventLevel.error,
          'SSH 连接失败',
          subject: '${profile.name} · $error',
        );
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

  /// Which topbar entry is highlighted. Sub-pages (forms, diagnostics) keep
  /// their parent highlighted so the nav never goes blank mid-task.
  AppSection get _currentSection => switch (contentMode) {
    WorkbenchContentMode.sshProfiles ||
    WorkbenchContentMode.sshProfileForm => AppSection.connections,
    WorkbenchContentMode.tunnelConfigs ||
    WorkbenchContentMode.tunnelConfigForm => AppSection.tunnels,
    WorkbenchContentMode.themeConfig => AppSection.theme,
    _ => AppSection.workbench,
  };

  void _handleNavigateSection(AppSection section) {
    switch (section) {
      case AppSection.workbench:
        setState(() {
          contentMode = WorkbenchContentMode.terminal;
        });
      case AppSection.connections:
        setState(() {
          contentMode = WorkbenchContentMode.sshProfiles;
          editingSshProfile = null;
          sshErrorMessage = null;
        });
        loadSshProfiles();
      case AppSection.tunnels:
        setState(() {
          contentMode = WorkbenchContentMode.tunnelConfigs;
          editingTunnelConfig = null;
          tunnelErrorMessage = null;
        });
        loadSshProfiles();
        loadTunnelConfigs();
      case AppSection.theme:
        _handleOpenThemeConfig();
    }
  }

  void _handleOpenThemeConfig() {
    setState(() {
      contentMode = WorkbenchContentMode.themeConfig;
    });
  }

  /// A highlight rule the terminal refused to compile. Surfaced in the dock's
  /// event feed because the symptom otherwise is silent: the colours just stop
  /// appearing and there is nothing on screen pointing at the bad pattern.
  void _handleRegexRuleError(String pattern, String message) {
    _events.record(
      WorkbenchEventLevel.error,
      '正则规则无效，已忽略',
      subject: '$pattern — $message',
    );
  }

  /// Toggles the dock's 内存监控 panel from the Explorer's footer button.
  void _handleToggleMemoryDock() {
    setState(() => _memoryDockVisible = !_memoryDockVisible);
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

  /// The Explorer belongs to the workbench only. The settings pages are
  /// full-bleed views under the topbar, exactly like the prototype — keeping
  /// the sidebar beside them would squeeze their tables into ~500px.
  bool get _showExplorer => switch (contentMode) {
    WorkbenchContentMode.terminal || WorkbenchContentMode.diagnostics => true,
    WorkbenchContentMode.sshProfiles ||
    WorkbenchContentMode.sshProfileForm ||
    WorkbenchContentMode.tunnelConfigs ||
    WorkbenchContentMode.tunnelConfigForm ||
    WorkbenchContentMode.themeConfig => false,
  };

  /// The form drawer floating over the shell, or null when none is open.
  ///
  /// The prototype mounts these as an overlay rather than swapping the page,
  /// so the list underneath stays mounted and survives the round trip.
  Widget? get _openDrawer => switch (contentMode) {
    WorkbenchContentMode.sshProfileForm => SshProfileFormDrawer(
      profile: editingSshProfile,
      onCancel: _handleCancelSshForm,
      onSaved: _handleSaveSshProfile,
    ),
    WorkbenchContentMode.tunnelConfigForm => TunnelConfigFormDrawer(
      profiles: sshProfiles,
      tunnel: editingTunnelConfig,
      onCancel: _handleCancelTunnelForm,
      onSaved: _handleSaveTunnelConfig,
    ),
    _ => null,
  };

  /// The dock belongs to the workbench page only, like the prototype's
  /// `.bench`; the settings pages have no bottom panels.
  bool get _showDock =>
      _showExplorer && contentMode == WorkbenchContentMode.terminal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ExplorerResizeHold(
        hold: _explorerResizeHold,
        child: Stack(
          children: [
            Column(
              children: [
                AppTopBar(
                  current: _currentSection,
                  onNavigate: _handleNavigateSection,
                  onAddConnection: _handleAddConnection,
                  sessionCount: terminalState.tabs.length,
                  tunnelCount: tunnelConfigs.length,
                  memoryRssMb: _memoryRssMb,
                  clock: _clock,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (_showExplorer) ...[
                              Sidebar(
                                width: _sidebarWidth,
                                // The prototype collapses the Explorer into an icon rail once
                                // the column gets too narrow to carry labels.
                                compact:
                                    _sidebarWidth <= Sidebar.compactBreakpoint,
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
                                  sshSessionsByProfileId:
                                      sshSessionsByProfileId,
                                  onSshProfileTap: (_) {},
                                  onSshSessionTap: _handleSshSessionTap,
                                  onEditSshSessionNote:
                                      _handleEditSshSessionNote,
                                  onCloseSshSession: _handleCloseSshSession,
                                  onDuplicateSshSession:
                                      _handleDuplicateSshSession,
                                  onCloseLocalTerminal:
                                      _handleCloseLocalTerminal,
                                  onOpenThemeConfig: _handleOpenThemeConfig,
                                  themeConfigActive:
                                      contentMode ==
                                      WorkbenchContentMode.themeConfig,
                                  onToggleMemoryDock: _handleToggleMemoryDock,
                                  memoryDockVisible: _memoryDockVisible,
                                  onReorderSessions: _handleReorderSessions,
                                  onReorderLocalTerminals:
                                      _handleReorderLocalTerminals,
                                  sectionOrder: explorerSectionOrder,
                                  onSectionOrderChanged:
                                      _handleExplorerSectionOrderChanged,
                                  compact:
                                      _sidebarWidth <=
                                      Sidebar.compactBreakpoint,
                                ),
                              ),
                              ResizeHandle(
                                value: _sidebarWidth,
                                min: _minSidebarWidth,
                                max: 560,
                                onChanged: (width) =>
                                    setState(() => _sidebarWidth = width),
                                onDraggingChanged: (dragging) =>
                                    _explorerResizeHold.value = dragging,
                              ),
                            ],
                            Expanded(
                              child: WorkbenchContentSwitcher(
                                mode: contentMode,
                                terminalState: terminalState,
                                sshProfiles: sshProfiles,
                                sshErrorMessage: sshErrorMessage,
                                editingSshProfile: editingSshProfile,
                                tunnelConfigs: tunnelConfigs,
                                tunnelErrorMessage: tunnelErrorMessage,
                                editingTunnelConfig: editingTunnelConfig,
                                uiThemeSettings: uiThemeSettings,
                                terminalThemeSettings: terminalThemeSettings,
                                onSelectTab: _handleTabSelect,
                                onCloseTab: _handleTabClose,
                                onReorderTab: _handleTabReorder,
                                onRegexRuleError: _handleRegexRuleError,
                                onAddSshProfile: _handleAddSshProfile,
                                onlineSshProfileIds: [
                                  for (final entry
                                      in sshSessionsByProfileId.entries)
                                    if (entry.value.isNotEmpty) entry.key,
                                ],
                                lastConnectedSshProfileAt: _lastConnectedAt,
                                onConnectSshProfile: _handleConnectSshProfile,
                                onEditSshProfile: _handleEditSshProfile,
                                onDeleteSshProfile: _handleDeleteSshProfile,
                                onCancelSshForm: _handleCancelSshForm,
                                onSaveSshProfile: _handleSaveSshProfile,
                                onAddTunnelConfig: _handleAddTunnelConfig,
                                onStartTunnelConfig: _handleStartTunnelConfig,
                                onStopTunnelConfig: _handleStopTunnelConfig,
                                onEditTunnelConfig: _handleEditTunnelConfig,
                                onDeleteTunnelConfig: _handleDeleteTunnelConfig,
                                onCancelTunnelForm: _handleCancelTunnelForm,
                                onSaveTunnelConfig: _handleSaveTunnelConfig,
                                onUiThemeChanged: _handleUiThemeChanged,
                                onTerminalThemeChanged:
                                    _handleTerminalThemeChanged,
                                onBackFromConfig: _handleBackFromConfig,
                                sshBridge: widget.sshBridge,
                                localTerminalBridge: widget.localTerminalBridge,
                                onSshInput:
                                    null, // command tracking removed; was causing setState on every Enter
                                onSshTerminalInput: _writeSshTerminalInput,
                                onPreviewLabelChanged:
                                    _handleActiveTabPreviewLabelChanged,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_showDock)
                        WorkbenchDock(
                          events: _events,
                          height: _dockHeight,
                          collapsed: _dockCollapsed,
                          showMemory: _memoryDockVisible,
                          onCollapsedChanged: (collapsed) =>
                              setState(() => _dockCollapsed = collapsed),
                          onHeightChanged: (height) => setState(() {
                            _dockCollapsed = false;
                            _dockHeight = height.clamp(96.0, 420.0);
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_openDrawer != null) _openDrawer!,
          ],
        ),
      ),
    );
  }
}
