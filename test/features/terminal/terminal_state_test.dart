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

  group('TerminalState.close', () {
    test('closing the active tab activates the tab that slides in', () {
      final tabs = [_tab('a'), _tab('b'), _tab('c')];
      final state = TerminalState(tabs: tabs, activeTabId: 'b');

      final result = state.close('b');

      expect(result.tabs.map((t) => t.id), ['a', 'c']);
      expect(result.activeTabId, 'c');
    });

    test('closing the right-most active tab falls back to its neighbour', () {
      final tabs = [_tab('a'), _tab('b'), _tab('c')];
      final state = TerminalState(tabs: tabs, activeTabId: 'c');

      final result = state.close('c');

      expect(result.tabs.map((t) => t.id), ['a', 'b']);
      expect(result.activeTabId, 'b');
    });

    test('closing a background tab leaves the active tab alone', () {
      final tabs = [_tab('a'), _tab('b'), _tab('c')];
      final state = TerminalState(tabs: tabs, activeTabId: 'c');

      final result = state.close('a');

      expect(result.tabs.map((t) => t.id), ['b', 'c']);
      expect(result.activeTabId, 'c');
    });

    test('closing the last remaining tab clears the active id', () {
      final state = TerminalState(tabs: [_tab('a')], activeTabId: 'a');

      final result = state.close('a');

      expect(result.tabs, isEmpty);
      expect(result.activeTabId, isNull);
    });
  });
}
