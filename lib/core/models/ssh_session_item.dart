import 'package:xterm/xterm.dart' as xterm;

class SshSessionItem {
  const SshSessionItem({
    required this.id,
    required this.profileId,
    required this.hostName,
    required this.title,
    this.sessionId,
    this.history = '',
    this.terminal,
  });

  final String id;
  final String profileId;
  final String hostName;
  final String title;
  final String? sessionId;
  final String history;
  final xterm.Terminal? terminal;

  SshSessionItem copyWith({
    String? sessionId,
    String? history,
    xterm.Terminal? terminal,
  }) {
    return SshSessionItem(
      id: id,
      profileId: profileId,
      hostName: hostName,
      title: title,
      sessionId: sessionId ?? this.sessionId,
      history: history ?? this.history,
      terminal: terminal ?? this.terminal,
    );
  }
}
