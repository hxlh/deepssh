import 'dart:async';
import 'dart:ui';

import 'package:deepssh/core/logging/app_logger.dart';
import 'package:deepssh/core/logging/frontend_error_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var originalFlutterErrorHandler = FlutterError.onError;

  setUp(() {
    originalFlutterErrorHandler = FlutterError.onError;
  });

  tearDown(() {
    FlutterError.onError = originalFlutterErrorHandler;
  });

  test(
    'logs Flutter framework errors and preserves the previous handler',
    () async {
      final logger = RecordingErrorLogger();
      final presented = <FlutterErrorDetails>[];
      FlutterError.onError = presented.add;

      installFrontendErrorHooks(
        logger: logger,
        setPlatformErrorHandler: (_) {},
      );
      final details = FlutterErrorDetails(
        exception: StateError('framework failed'),
        stack: StackTrace.fromString('framework stack'),
        library: 'test',
      );

      FlutterError.onError!(details);
      await Future<void>.delayed(Duration.zero);

      expect(logger.entries.single.scope, 'frontend.flutter');
      expect(
        logger.entries.single.error.toString(),
        contains('framework failed'),
      );
      expect(presented.single, same(details));
    },
  );

  test('logs platform dispatcher errors and keeps them unhandled', () async {
    final logger = RecordingErrorLogger();
    ErrorCallback? platformHandler;

    installFrontendErrorHooks(
      logger: logger,
      setPlatformErrorHandler: (handler) {
        platformHandler = handler;
      },
    );

    final handled = platformHandler!(
      StateError('platform failed'),
      StackTrace.fromString('platform stack'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(handled, isFalse);
    expect(logger.entries.single.scope, 'frontend.platform');
    expect(logger.entries.single.error.toString(), contains('platform failed'));
  });

  test('runLoggedApp logs zone errors', () async {
    final logger = RecordingErrorLogger();

    runLoggedApp(
      const SizedBox.shrink(),
      logger: logger,
      runAppOverride: (_) {
        scheduleMicrotask(() {
          throw StateError('zone failed');
        });
      },
      setPlatformErrorHandler: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(logger.entries.single.scope, 'frontend.zone');
    expect(logger.entries.single.error.toString(), contains('zone failed'));
  });
}

class RecordingErrorLogger implements ErrorLogger {
  final entries = <LoggedError>[];

  @override
  Future<void> error(String scope, Object error, StackTrace? stackTrace) async {
    entries.add(LoggedError(scope, error, stackTrace));
  }
}

class LoggedError {
  LoggedError(this.scope, this.error, this.stackTrace);

  final String scope;
  final Object error;
  final StackTrace? stackTrace;
}
