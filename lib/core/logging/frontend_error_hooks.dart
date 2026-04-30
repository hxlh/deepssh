import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_logger.dart';

typedef PlatformErrorHandlerSetter = void Function(ErrorCallback? handler);

void installFrontendErrorHooks({
  required ErrorLogger logger,
  PlatformErrorHandlerSetter? setPlatformErrorHandler,
}) {
  final previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(
      logger.error('frontend.flutter', details.exception, details.stack),
    );
    if (previousFlutterErrorHandler != null) {
      previousFlutterErrorHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final installPlatformHandler =
      setPlatformErrorHandler ??
      (handler) {
        PlatformDispatcher.instance.onError = handler;
      };
  installPlatformHandler((error, stackTrace) {
    unawaited(logger.error('frontend.platform', error, stackTrace));
    return false;
  });
}

void runLoggedApp(
  Widget app, {
  ErrorLogger? logger,
  void Function(Widget app)? runAppOverride,
  PlatformErrorHandlerSetter? setPlatformErrorHandler,
}) {
  final errorLogger = logger ?? FileErrorLogger.frontend();
  runZonedGuarded(
    () {
      installFrontendErrorHooks(
        logger: errorLogger,
        setPlatformErrorHandler: setPlatformErrorHandler,
      );
      final startApp = runAppOverride ?? runApp;
      startApp(app);
    },
    (error, stackTrace) {
      unawaited(errorLogger.error('frontend.zone', error, stackTrace));
    },
  );
}
