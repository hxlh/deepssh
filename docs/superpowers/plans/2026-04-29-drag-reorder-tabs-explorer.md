# Drag Reorder for Tabs and Explorer Items

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable drag-to-reorder for terminal tabs (horizontal) and explorer sidebar items (vertical), using Flutter's built-in `ReorderableListView`.

**Architecture:** Replace `ListView.builder` with `ReorderableListView.builder` in both `TabStrip` and `HostTree`. The explorer's single flat `ListView` is split into sectioned groups (profiles, sessions-per-profile, local terminals) inside a `SingleChildScrollView`, each group being its own `ReorderableListView` with `shrinkWrap: true` and `NeverScrollableScrollPhysics()`.

**Tech Stack:** Flutter (no new dependencies — `ReorderableListView` is built-in)

---

### Task 1: Add `reorder` to `TerminalState`

**Files:**
- Modify: `lib/features/terminal/terminal_state.dart:99-146`

- [ ] **Step 1: Add the `reorder` method**

Add this method inside the `TerminalState` class, after the `close` method (line 145):

```dart
TerminalState reorder(int oldIndex, int newIndex) {
  final nextTabs = [...tabs];
  final tab = nextTabs.removeAt(oldIndex);
  final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
  nextTabs.insert(insertAt, tab);
  return TerminalState(tabs: nextTabs, activeTabId: activeTabId);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/terminal/terminal_state.dart
git commit -m "feat: add TerminalState.reorder for tab drag reorder"
```

---

### Task 2: Convert `TabStrip` to `ReorderableListView`

**Files:**
- Modify: `lib/workbench/widgets/tab_strip.dart`

- [ ] **Step 1: Replace `ListView.builder` with `ReorderableListView.builder`**

Replace the `build` method (lines 22-44) and the `_TabItem` `key` usage. The `_TabItem` widget also needs a `key` parameter.

Change the `_TabItem` constructor to take a `key`:

```dart
class _TabItem extends StatefulWidget {
  const _TabItem({
    super.key,  // add this
    required this.tab,
    required this.active,
    required this.onSelect,
    required this.onClose,
  });
```

Replace the `build` method of `TabStrip` **and** add `onReorder` param:

```dart
class TabStrip extends StatelessWidget {
  const TabStrip({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onSelect,
    required this.onClose,
    required this.onReorder,
  });

  final List<OpenTerminalTab> tabs;
  final String? activeTabId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.tabHeight,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        onReorder: onReorder,
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final opacity = 1.0 - 0.3 * animation.value;
              return Opacity(opacity: opacity, child: child);
            },
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final active = tab.id == activeTabId;
          return _TabItem(
            key: ValueKey(tab.id),
            tab: tab,
            active: active,
            onSelect: () => onSelect(tab.id),
            onClose: () => onClose(tab.id),
          );
        },
      ),
    );
  }
}
```

(Note: `buildDefaultDragHandles: false` — Flutter doesn't support this for `ReorderableListView.builder`. Remove that line.)

- [ ] **Step 2: Wrap each `_TabItem` in a drag handle**

Wrap the `GestureDetector` inside `_TabItemState.build` with `ReorderableDragStartListener`:

Change the `return MouseRegion(...)` in `_TabItemState.build` to:

```dart
return ReorderableDragStartListener(
  index: -1, // We'll pass index from the parent
  enabled: true,
  child: MouseRegion(
    // ... existing MouseRegion content unchanged
  ),
);
```

Wait, `ReorderableDragStartListener` needs the index. The cleanest approach: pass `index` to `_TabItem` and use `ReorderableDragStartListener` for long-press drag initiation.

Actually, `ReorderableListView` by default uses long-press on the item itself. Since `buildDefaultDragHandles` doesn't exist as an option on `ReorderableListView.builder`, let's just use the default behavior — long-press anywhere on the tab initiates drag. Remove the `buildDefaultDragHandles` line.

**Final version of the `build` method:**

```dart
@override
Widget build(BuildContext context) {
  return Container(
    height: AppSpacing.tabHeight,
    decoration: BoxDecoration(
      color: AppColors.background,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: tabs.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final tab = tabs[index];
        final active = tab.id == activeTabId;
        return _TabItem(
          key: ValueKey(tab.id),
          tab: tab,
          active: active,
          onSelect: () => onSelect(tab.id),
          onClose: () => onClose(tab.id),
        );
      },
    ),
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/workbench/widgets/tab_strip.dart
git commit -m "feat: convert TabStrip to ReorderableListView for drag reorder"
```

---

### Task 3: Wire `onReorder` through `TerminalTabShell` and `WorkbenchContentSwitcher`

**Files:**
- Modify: `lib/features/terminal/terminal_tab_shell.dart`
- Modify: `lib/workbench/widgets/workbench_content_switcher.dart`
- Modify: `lib/workbench/workbench_page.dart`

- [ ] **Step 1: Add `onReorderTab` to `TerminalTabShell`**

Add the parameter to the constructor (after `onCloseTab`) and pass to `TabStrip`:

```dart
const TerminalTabShell({
  // ... existing params ...
  required this.onCloseTab,
  required this.onReorderTab,   // <-- add
  // ...
});

final ValueChanged<String> onCloseTab;
final void Function(int oldIndex, int newIndex) onReorderTab;  // <-- add
```

In `build` method, pass it to `TabStrip`:

```dart
TabStrip(
  tabs: widget.state.tabs,
  activeTabId: widget.state.activeTabId,
  onSelect: widget.onSelectTab,
  onClose: widget.onCloseTab,
  onReorder: widget.onReorderTab,  // <-- add
),
```

- [ ] **Step 2: Add `onReorderTab` to `WorkbenchContentSwitcher`**

Add parameter (after `onCloseTab`):

```dart
final ValueChanged<String> onCloseTab;
final void Function(int oldIndex, int newIndex) onReorderTab;  // <-- add
```

In `build`, pass to `TerminalTabShell`:

```dart
return TerminalTabShell(
  state: terminalState,
  onSelectTab: onSelectTab,
  onCloseTab: onCloseTab,
  onReorderTab: onReorderTab,  // <-- add
  sshBridge: sshBridge,
  terminalThemeSettings: terminalThemeSettings,
  onSshInput: onSshInput,
);
```

- [ ] **Step 3: Add `_handleTabReorder` in `WorkbenchPage`**

Add the handler method in `_WorkbenchPageState`:

```dart
void _handleTabReorder(int oldIndex, int newIndex) {
  setState(() {
    terminalState = terminalState.reorder(oldIndex, newIndex);
  });
}
```

In `build`, pass to `WorkbenchContentSwitcher`:

```dart
WorkbenchContentSwitcher(
  // ... existing params ...
  onCloseTab: _handleTabClose,
  onReorderTab: _handleTabReorder,  // <-- add
  // ...
),
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/terminal/terminal_tab_shell.dart lib/workbench/widgets/workbench_content_switcher.dart lib/workbench/workbench_page.dart
git commit -m "feat: wire tab reorder callback through to WorkbenchPage"
```

---

### Task 4: Restructure `HostTree` with sectioned `ReorderableListView`s

**Files:**
- Modify: `lib/features/hosts/host_tree.dart`
- Modify: `lib/workbench/workbench_page.dart` (add callbacks + pass through)

- [ ] **Step 1: Add reorder callbacks to `HostTree`**

Add three new callback parameters to the `HostTree` constructor:

```dart
final void Function(int oldIndex, int newIndex)? onReorderProfiles;
final void Function(String profileId, int oldIndex, int newIndex)? onReorderSessions;
final void Function(int oldIndex, int newIndex)? onReorderLocalTerminals;
```

- [ ] **Step 2: Restructure `HostTree.build` method**

Replace the single `ListView` in the `build` method with a `Column` inside a `SingleChildScrollView`. Each logical section becomes its own `ReorderableListView`.

The new `build` method structure:

```dart
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- SSH Profiles section ---
              if (sshProfiles.isNotEmpty) ...[
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sshProfiles.length,
                  onReorder: onReorderProfiles ?? (_, __) {},
                  itemBuilder: (context, profileIndex) {
                    final profile = sshProfiles[profileIndex];
                    final sessions = sshSessionsByProfileId[profile.id] ?? const <SshSessionItem>[];
                    return Column(
                      key: ValueKey('profile-${profile.id}'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Profile header (non-reorderable)
                        InkWell(
                          onTap: () => onSshProfileTap(profile),
                          child: Container(
                            height: AppSpacing.itemHeight,
                            margin: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                Icon(Icons.computer, size: 16, color: AppColors.textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(profile.name, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Sessions under this profile (reorderable)
                        if (sessions.isNotEmpty)
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sessions.length,
                            onReorder: (oldIndex, newIndex) {
                              onReorderSessions?.call(profile.id, oldIndex, newIndex);
                            },
                            itemBuilder: (context, sessionIndex) {
                              final session = sessions[sessionIndex];
                              return _sessionItem(context, session);
                            },
                          ),
                      ],
                    );
                  },
                ),
              ],
              // --- Host nodes (non-SSH, fallback) ---
              if (sshProfiles.isEmpty)
                ...state.hosts.map((host) {
                  return HostTreeNode(
                    key: ValueKey('host-${host.id}'),
                    host: host,
                    expanded: state.isExpanded(host.id),
                    selectedTerminalId: selectedTerminalId,
                    onToggle: () => onToggleHost(host.id),
                    onTerminalTap: onTerminalTap,
                  );
                }),
              // --- Local terminals section ---
              if (localTerminals.isNotEmpty) ...[
                InkWell(
                  onTap: onToggleLocal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      height: AppSpacing.itemHeight,
                      child: Row(
                        children: [
                          Icon(
                            localExpanded ? Icons.expand_more : Icons.chevron_right,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          Icon(Icons.laptop, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          const Text('Local'),
                        ],
                      ),
                    ),
                  ),
                ),
                if (localExpanded)
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: localTerminals.length,
                    onReorder: onReorderLocalTerminals ?? (_, __) {},
                    itemBuilder: (context, index) {
                      final terminal = localTerminals[index];
                      return _localTerminalItem(context, terminal);
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
      _ThemeConfigButton(active: themeConfigActive, onTap: onOpenThemeConfig),
    ],
  );
}
```

- [ ] **Step 3: Extract item builders as helper methods**

Extract session and local terminal item builders to avoid code duplication with context menus:

```dart
Widget _sessionItem(BuildContext context, SshSessionItem session) {
  return InkWell(
    key: ValueKey('session-${session.id}'),
    onTap: () => onSshSessionTap(session),
    onSecondaryTapDown: (details) {
      _showSshSessionMenu(
        context: context,
        position: details.globalPosition,
        onEditNote: () => onEditSshSessionNote(session),
        onDuplicate: () => onDuplicateSshSession(session),
        onClose: () => onCloseSshSession(session),
      );
    },
    child: Container(
      height: AppSpacing.itemHeight,
      margin: const EdgeInsets.fromLTRB(24, 2, 8, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: selectedTerminalId == session.id ? AppColors.selection : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(session.displayTitle, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
  );
}

Widget _localTerminalItem(BuildContext context, LocalTerminalItem terminal) {
  return InkWell(
    key: ValueKey('local-${terminal.id}'),
    onTap: () => onLocalTerminalTap(terminal),
    onSecondaryTapDown: (details) {
      _showCloseMenu(
        context: context,
        position: details.globalPosition,
        label: '关闭终端',
        onClose: () => onCloseLocalTerminal(terminal),
      );
    },
    child: Container(
      height: AppSpacing.itemHeight,
      margin: const EdgeInsets.fromLTRB(24, 2, 8, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: selectedTerminalId == terminal.id ? AppColors.selection : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(terminal.title, overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
  );
}
```

Remove the inline `InkWell` sessions and local terminal items from the old `build` — they are now generated by these helpers in the appropriate `ReorderableListView`.

- [ ] **Step 4: Add reorder handlers in `WorkbenchPage`**

```dart
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
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    sessions.insert(insertAt, item);
    sshSessionsByProfileId = {...sshSessionsByProfileId, profileId: sessions};
  });
}

void _handleReorderLocalTerminals(int oldIndex, int newIndex) {
  setState(() {
    final next = [...localTerminals];
    final item = next.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    next.insert(insertAt, item);
    localTerminals = next;
  });
}
```

- [ ] **Step 5: Pass callbacks from `WorkbenchPage.build` to `HostTree`**

In `WorkbenchPage.build`, update the `HostTree(...)` call to include the three new parameters:

```dart
HostTree(
  // ... existing params unchanged ...
  onReorderProfiles: _handleReorderProfiles,
  onReorderSessions: _handleReorderSessions,
  onReorderLocalTerminals: _handleReorderLocalTerminals,
),
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/hosts/host_tree.dart lib/workbench/workbench_page.dart
git commit -m "feat: add drag reorder to explorer sidebar items"
```

---

### Task 5: Verify builds

- [ ] **Step 1: Run analysis**

```bash
flutter analyze
```
Expected: no errors.

- [ ] **Step 2: Run build**

```bash
flutter build windows --debug
```
Expected: build succeeds.

- [ ] **Step 3: Commit any fixes**

If analysis or build revealed issues, fix and commit.

