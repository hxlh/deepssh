import 'dart:io';

import 'package:deepssh/core/logging/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileErrorLogger', () {
    test('writes frontend errors to a daily log file under config log', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'deepssh-log-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final logger = FileErrorLogger(
        filePrefix: 'frontend',
        platform: AppLogPlatform(
          isMacOS: false,
          homeDirectory: null,
          currentDirectory: tempDir.path,
        ),
        now: () => DateTime(2026, 4, 30, 21, 45, 12, 345),
      );

      await logger.error(
        'ssh.connect',
        StateError('Connection failed password=secret'),
        StackTrace.fromString('stack line'),
      );

      final logFile = File(
        '${tempDir.path}${Platform.pathSeparator}config${Platform.pathSeparator}log${Platform.pathSeparator}frontend-2026-04-30.log',
      );
      final content = await logFile.readAsString();
      expect(
        content,
        contains('2026-04-30T21:45:12.345 ERROR frontend ssh.connect'),
      );
      expect(
        content,
        contains('Bad state: Connection failed password=<redacted>'),
      );
      expect(content, contains('stack line'));
      expect(content, isNot(contains('secret')));
    });

    test('redacts quoted secret values that contain spaces', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'deepssh-log-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final logger = FileErrorLogger(
        filePrefix: 'frontend',
        platform: AppLogPlatform(
          isMacOS: false,
          homeDirectory: null,
          currentDirectory: tempDir.path,
        ),
        now: () => DateTime(2026, 4, 30),
      );

      await logger.error(
        'ssh.connect',
        StateError(
          'Connection failed password="alpha beta" token: \'gamma delta\'',
        ),
        null,
      );

      final logFile = File(
        '${tempDir.path}${Platform.pathSeparator}config${Platform.pathSeparator}log${Platform.pathSeparator}frontend-2026-04-30.log',
      );
      final content = await logFile.readAsString();
      expect(content, contains('password=<redacted>'));
      expect(content, contains('token=<redacted>'));
      expect(content, isNot(contains('alpha')));
      expect(content, isNot(contains('beta')));
      expect(content, isNot(contains('gamma')));
      expect(content, isNot(contains('delta')));
    });

    test('uses macOS Application Support config root', () {
      final platform = AppLogPlatform(
        isMacOS: true,
        homeDirectory: '/Users/alex',
        currentDirectory: '/repo/deepssh',
      );

      final logDirectory = platform.logDirectory();

      expect(
        logDirectory.path,
        '/Users/alex${Platform.pathSeparator}Library${Platform.pathSeparator}Application Support${Platform.pathSeparator}deepssh${Platform.pathSeparator}log',
      );
    });

    test('falls back to relative config root when macOS home is unavailable', () {
      final platform = AppLogPlatform(
        isMacOS: true,
        homeDirectory: null,
        currentDirectory: '/repo/deepssh',
      );

      final logDirectory = platform.logDirectory();

      expect(
        logDirectory.path,
        '/repo/deepssh${Platform.pathSeparator}config${Platform.pathSeparator}log',
      );
    });

    test('does not throw when writing the log file fails', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'deepssh-log-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final configFile = File('${tempDir.path}${Platform.pathSeparator}config');
      await configFile.writeAsString('not a directory');
      final logger = FileErrorLogger(
        filePrefix: 'frontend',
        platform: AppLogPlatform(
          isMacOS: false,
          homeDirectory: null,
          currentDirectory: tempDir.path,
        ),
        now: () => DateTime(2026, 4, 30),
      );

      await expectLater(
        logger.error(
          'theme.save',
          StateError('disk failed'),
          StackTrace.current,
        ),
        completes,
      );
    });
  });
}
