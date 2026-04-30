import 'package:deepssh/features/terminal/terminal_state.dart';
import 'package:flutter_test/flutter_test.dart';

OpenTerminalTab _tab(String id) => OpenTerminalTab.local(id: id, title: id);

void main() {
  group('TerminalState.reorder', () {
    test('moves a tab from index 0 to index 2', () {
      final tabs = [_tab('a'), _tab('b'), _tab('c'), _tab('d')];
      final state = TerminalState(tabs: tabs, activeTabId: 'a');

      final result = state.reorder(0, 2);

      expect(result.tabs.map((t) => t.id), ['b', 'a', 'c', 'd']);
    });

    test('moves a tab from higher to lower index', () {
      final tabs = [_tab('a'), _tab('b'), _tab('c')];
      final state = TerminalState(tabs: tabs, activeTabId: 'a');

      final result = state.reorder(2, 0);

      expect(result.tabs.map((t) => t.id), ['c', 'a', 'b']);
    });

    test('preserves activeTabId after reorder', () {
      final tabs = [_tab('a'), _tab('b'), _tab('c')];
      final state = TerminalState(tabs: tabs, activeTabId: 'b');

      final result = state.reorder(0, 2);

      expect(result.activeTabId, 'b');
    });

    test('same index is a no-op', () {
      final tabs = [_tab('a'), _tab('b')];
      final state = TerminalState(tabs: tabs, activeTabId: 'a');

      final result = state.reorder(0, 0);

      expect(result.tabs.map((t) => t.id), ['a', 'b']);
    });
  });
}
