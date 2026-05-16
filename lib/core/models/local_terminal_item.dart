import 'package:xterm/xterm.dart' as xterm;

class LocalTerminalItem {
  const LocalTerminalItem({
    required this.id,
    required this.title,
    this.previewLabel = '',
    this.sessionId,
    this.terminal,
  });

  final String id;
  final String title;
  final String previewLabel;
  final String? sessionId;
  final xterm.Terminal? terminal;

  String get displayTitle {
    final trimmedPreview = previewLabel.trim();
    if (trimmedPreview.isNotEmpty) return trimmedPreview;
    return title;
  }

  LocalTerminalItem copyWith({
    String? previewLabel,
    String? sessionId,
    xterm.Terminal? terminal,
  }) {
    return LocalTerminalItem(
      id: id,
      title: title,
      previewLabel: previewLabel ?? this.previewLabel,
      sessionId: sessionId ?? this.sessionId,
      terminal: terminal ?? this.terminal,
    );
  }
}
