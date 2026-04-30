import 'dart:io';

abstract interface class ErrorLogger {
  Future<void> error(String scope, Object error, StackTrace? stackTrace);
}

class NoopErrorLogger implements ErrorLogger {
  const NoopErrorLogger();

  @override
  Future<void> error(
    String scope,
    Object error,
    StackTrace? stackTrace,
  ) async {}
}

class AppLogPlatform {
  const AppLogPlatform({
    required this.isMacOS,
    required this.homeDirectory,
    required this.currentDirectory,
  });

  factory AppLogPlatform.current() {
    return AppLogPlatform(
      isMacOS: Platform.isMacOS,
      homeDirectory: Platform.environment['HOME'],
      currentDirectory: Directory.current.path,
    );
  }

  final bool isMacOS;
  final String? homeDirectory;
  final String currentDirectory;

  Directory configDirectory() {
    final home = homeDirectory;
    if (isMacOS && home != null && home.isNotEmpty) {
      return Directory(
        [
          home,
          'Library',
          'Application Support',
          'deepssh',
        ].join(Platform.pathSeparator),
      );
    }
    return Directory([currentDirectory, 'config'].join(Platform.pathSeparator));
  }

  Directory logDirectory() {
    return Directory(
      [configDirectory().path, 'log'].join(Platform.pathSeparator),
    );
  }
}

class FileErrorLogger implements ErrorLogger {
  FileErrorLogger({
    required this.filePrefix,
    AppLogPlatform? platform,
    DateTime Function()? now,
  }) : platform = platform ?? AppLogPlatform.current(),
       _now = now ?? DateTime.now;

  factory FileErrorLogger.frontend() {
    return FileErrorLogger(filePrefix: 'frontend');
  }

  final String filePrefix;
  final AppLogPlatform platform;
  final DateTime Function() _now;

  @override
  Future<void> error(String scope, Object error, StackTrace? stackTrace) async {
    try {
      final timestamp = _now();
      final logDirectory = platform.logDirectory();
      await logDirectory.create(recursive: true);
      final logFile = File(
        [
          logDirectory.path,
          '$filePrefix-${_dateStamp(timestamp)}.log',
        ].join(Platform.pathSeparator),
      );
      await logFile.writeAsString(
        _entry(timestamp, scope, error, stackTrace),
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  String _entry(
    DateTime timestamp,
    String scope,
    Object error,
    StackTrace? stackTrace,
  ) {
    final safeScope = scope.trim().replaceAll(RegExp(r'\s+'), '_');
    final buffer = StringBuffer()
      ..writeln('${_timestamp(timestamp)} ERROR $filePrefix $safeScope')
      ..writeln(_redact(error.toString()));
    if (stackTrace != null) {
      buffer.writeln(_redact(stackTrace.toString()));
    }
    return buffer.toString();
  }

  String _timestamp(DateTime value) {
    return value.toLocal().toIso8601String();
  }

  String _dateStamp(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _redact(String value) {
    return value.replaceAllMapped(
      RegExp(
        "\\b(password|passwd|secret|token)\\s*[:=]\\s*(?:\"[^\"]*\"|'[^']*'|[^\\s,;]+)",
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=<redacted>',
    );
  }
}
