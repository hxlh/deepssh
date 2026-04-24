import '../../core/models/host_item.dart';
import '../../core/models/terminal_item.dart';

enum TerminalSourceType { remote, local }

class OpenTerminalTab {
  const OpenTerminalTab({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.title,
    required this.sourceType,
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

  factory OpenTerminalTab.local({required String id, required String title}) {
    return OpenTerminalTab(
      id: id,
      hostId: 'local',
      hostName: 'local',
      title: title,
      sourceType: TerminalSourceType.local,
    );
  }

  final String id;
  final String hostId;
  final String hostName;
  final String title;
  final TerminalSourceType sourceType;

  String get label => '$hostName · $title';

  String get welcomeTarget {
    switch (sourceType) {
      case TerminalSourceType.local:
        return 'local / $title';
      case TerminalSourceType.remote:
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
      return TerminalState(tabs: tabs, activeTabId: tab.id);
    }
    return TerminalState(tabs: [...tabs, tab], activeTabId: tab.id);
  }

  TerminalState activate(String tabId) {
    return TerminalState(tabs: tabs, activeTabId: tabId);
  }

  TerminalState close(String tabId) {
    final nextTabs = tabs.where((tab) => tab.id != tabId).toList();
    final nextActiveId = nextTabs.isEmpty ? null : nextTabs.last.id;
    return TerminalState(tabs: nextTabs, activeTabId: nextActiveId);
  }
}
