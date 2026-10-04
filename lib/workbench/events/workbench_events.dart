import 'package:flutter/foundation.dart';

enum WorkbenchEventLevel { info, warn, error }

/// One entry in the workbench event feed.
///
/// The prototype folds errors into the same stream as ordinary events and
/// carries severity on a left rule plus a mono chip, so an error never gets a
/// separate panel.
@immutable
class WorkbenchEvent {
  const WorkbenchEvent({
    required this.time,
    required this.level,
    required this.message,
    this.subject,
  });

  final DateTime time;
  final WorkbenchEventLevel level;
  final String message;

  /// The thing the event is about (a profile, a tunnel, a session).
  final String? subject;
}

/// In-memory ring buffer of workbench events, newest first.
///
/// Deliberately not persisted: the prototype treats the feed as an observation
/// surface for the running app, not as a log file. Backend errors still go to
/// the on-disk backend log via `ErrorLogger`.
class WorkbenchEvents extends ChangeNotifier {
  static const int _maxEntries = 200;

  final List<WorkbenchEvent> _entries = <WorkbenchEvent>[];

  List<WorkbenchEvent> get entries => List.unmodifiable(_entries);

  void record(WorkbenchEventLevel level, String message, {String? subject}) {
    _entries.insert(
      0,
      WorkbenchEvent(
        time: DateTime.now(),
        level: level,
        message: message,
        subject: subject,
      ),
    );
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    notifyListeners();
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }
}
