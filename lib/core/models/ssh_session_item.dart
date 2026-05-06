import 'package:xterm/xterm.dart' as xterm;

class SshSessionItem {
  const SshSessionItem({
    required this.id,
    required this.profileId,
    required this.hostName,
    required this.title,
    this.note = '',
    this.currentCommand = '',
    this.sessionId,
    this.history = '',
    this.terminal,
    this.connectionGroupId = '',
  });

  final String id;
  final String profileId;
  final String hostName;
  final String title;
  final String note;
  final String currentCommand;
  final String? sessionId;
  final String history;
  final xterm.Terminal? terminal;
  final String connectionGroupId;

  String get displayTitle {
    final trimmedNote = note.trim();
    if (trimmedNote.isNotEmpty) return trimmedNote;
    final trimmedCurrentCommand = currentCommand.trim();
    if (trimmedCurrentCommand.isNotEmpty) return trimmedCurrentCommand;
    return title;
  }

  SshSessionItem copyWith({
    String? note,
    String? currentCommand,
    String? sessionId,
    String? history,
    xterm.Terminal? terminal,
    String? connectionGroupId,
  }) {
    return SshSessionItem(
      id: id,
      profileId: profileId,
      hostName: hostName,
      title: title,
      note: note ?? this.note,
      currentCommand: currentCommand ?? this.currentCommand,
      sessionId: sessionId ?? this.sessionId,
      history: history ?? this.history,
      terminal: terminal ?? this.terminal,
      connectionGroupId: connectionGroupId ?? this.connectionGroupId,
    );
  }
}
