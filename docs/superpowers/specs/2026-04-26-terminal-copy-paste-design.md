# Terminal Right-Click Copy/Paste — Design Spec

## Goal

Add a right-click context menu to the terminal view with "Copy" and "Paste" options. Copy reads the current terminal selection to the system clipboard; Paste writes clipboard text into the terminal input. "Copy" is disabled (greyed out) when no text is selected.

## Menu Behavior

- **Trigger:** Right-click anywhere on the terminal view
- **Position:** Popup at mouse cursor position, using Flutter's `showMenu()`
- **Style:** Consistent with existing Explorer right-click menus (PopupMenuItem)

## Menu Items

1. **复制 (Copy)**
   - Reads `terminal.selection` to get selected text
   - Writes to system clipboard via `Clipboard.setData()`
   - `enabled: false` when `terminal.selection` is null or empty

2. **粘贴 (Paste)**
   - Reads from system clipboard via `Clipboard.getData()`
   - Sends text to terminal via `terminal.textInput(pastedText)`
   - Always enabled

## Implementation

- Add right-click handler in `TerminalView` widget's `Listener` (`onPointerDown` checking for `PointerButton.secondary`)
- Use existing `showMenu()` pattern from `host_tree.dart`
- Access xterm `Terminal` object (already available in `TerminalView`) for selection and text input
- No changes to Rust backend — purely Dart/Flutter frontend

## Scope

- Trigger: right-click only (no keyboard shortcuts, no middle-click)
- No "Select All" or other menu items — just Copy and Paste
