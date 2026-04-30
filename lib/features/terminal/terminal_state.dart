import 'package:xterm/xterm.dart' as xterm;

import '../../core/models/host_item.dart';
import '../../core/models/terminal_item.dart';

enum TerminalSourceType { remote, local, ssh }

class OpenTerminalTab {
  const OpenTerminalTab({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.title,
    required this.sourceType,
    this.sessionId,
    this.history = '',
    this.terminal,
  });

  factory OpenTerminalTab.fromItems(HostItem host, TerminalItem terminal) {
    return OpenTerminalTab(
      id: terminal.id,
      hostId: host.id,
      hostName: host.name,
      title: terminal.title,
      sourceType: TerminalSourceType.remote,
    );
  }

  factory OpenTerminalTab.local({
    required String id,
    required String title,
    String? sessionId,
    xterm.Terminal? terminal,
  }) {
    return OpenTerminalTab(
      id: id,
      hostId: 'local',
      hostName: 'local',
      title: title,
      sourceType: TerminalSourceType.local,
      sessionId: sessionId,
      terminal: terminal,
    );
  }

  factory OpenTerminalTab.ssh({
    required String id,
    required String hostName,
    required String title,
    String? sessionId,
    String history = '',
    xterm.Terminal? terminal,
  }) {
    return OpenTerminalTab(
      id: id,
      hostId: 'ssh',
      hostName: hostName,
      title: title,
      sourceType: TerminalSourceType.ssh,
      sessionId: sessionId,
      history: history,
      terminal: terminal,
    );
  }

  final String id;
  final String hostId;
  final String hostName;
  final String title;
  final TerminalSourceType sourceType;
  final String? sessionId;
  final String history;
  final xterm.Terminal? terminal;

  OpenTerminalTab copyWith({
    String? sessionId,
    String? history,
    xterm.Terminal? terminal,
  }) {
    return OpenTerminalTab(
      id: id,
      hostId: hostId,
      hostName: hostName,
      title: title,
      sourceType: sourceType,
      sessionId: sessionId ?? this.sessionId,
      history: history ?? this.history,
      terminal: terminal ?? this.terminal,
    );
  }

  String get label => '$hostName · $title';

  String get welcomeTarget {
    switch (sourceType) {
      case TerminalSourceType.local:
        return 'local / $title';
      case TerminalSourceType.remote:
      case TerminalSourceType.ssh:
        return '$hostName / $title';
    }
  }
}

class TerminalState {
  const TerminalState({this.tabs = const [], this.activeTabId});

  final List<OpenTerminalTab> tabs;
  final String? activeTabId;

  OpenTerminalTab? get activeTab {
    for (final tab in tabs) {
      if (tab.id == activeTabId) {
        return tab;
      }
    }
    return null;
  }

  TerminalState open(OpenTerminalTab tab) {
    final existingIndex = tabs.indexWhere((item) => item.id == tab.id);
    if (existingIndex != -1) {
      final nextTabs = [...tabs];
      nextTabs[existingIndex] = tab;
      return TerminalState(tabs: nextTabs, activeTabId: tab.id);
    }
    return TerminalState(tabs: [...tabs, tab], activeTabId: tab.id);
  }

  TerminalState update(OpenTerminalTab tab) {
    final existingIndex = tabs.indexWhere((item) => item.id == tab.id);
    if (existingIndex == -1) return this;
    final nextTabs = [...tabs];
    nextTabs[existingIndex] = tab;
    return TerminalState(tabs: nextTabs, activeTabId: activeTabId);
  }

  TerminalState activate(String tabId) {
    return TerminalState(tabs: tabs, activeTabId: tabId);
  }

  TerminalState close(String tabId) {
    final existingIndex = tabs.indexWhere((tab) => tab.id == tabId);
    if (existingIndex == -1) return this;
    final nextTabs = [
      ...tabs.take(existingIndex),
      ...tabs.skip(existingIndex + 1),
    ];
    final nextActiveId = nextTabs.isEmpty ? null : nextTabs.last.id;
    return TerminalState(tabs: nextTabs, activeTabId: nextActiveId);
  }

  TerminalState reorder(int oldIndex, int newIndex) {
    final nextTabs = [...tabs];
    final tab = nextTabs.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    nextTabs.insert(insertAt, tab);
    return TerminalState(tabs: nextTabs, activeTabId: activeTabId);
  }
}
