import 'package:xterm/xterm.dart' as xterm;

class LocalTerminalItem {
  const LocalTerminalItem({
    required this.id,
    required this.title,
    this.sessionId,
    this.terminal,
  });

  final String id;
  final String title;
  final String? sessionId;
  final xterm.Terminal? terminal;

  LocalTerminalItem copyWith({String? sessionId, xterm.Terminal? terminal}) {
    return LocalTerminalItem(
      id: id,
      title: title,
      sessionId: sessionId ?? this.sessionId,
      terminal: terminal ?? this.terminal,
    );
  }
}
