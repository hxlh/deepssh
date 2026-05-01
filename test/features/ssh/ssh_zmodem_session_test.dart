import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:deepssh/core/logging/app_logger.dart';
import 'package:deepssh/features/ssh/ssh_zmodem_file_picker.dart';
import 'package:deepssh/features/ssh/ssh_zmodem_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart' as xterm;

class FakeErrorLogger implements ErrorLogger {
  final entries = <({String scope, Object error})>[];

  @override
  Future<void> error(String scope, Object error, StackTrace? stackTrace) async {
    entries.add((scope: scope, error: error));
  }
}

class FakeOffer implements xterm.ZModemOffer {
  FakeOffer(this.info, this.stream);

  @override
  final xterm.ZModemFileInfo info;

  final Stream<Uint8List> stream;
  var acceptedOffsets = <int>[];
  var skipped = false;

  @override
  Stream<Uint8List> accept(int offset) {
    acceptedOffsets.add(offset);
    return stream;
  }

  @override
  void skip() {
    skipped = true;
  }
}

void main() {
  test('formats known-size progress as a terminal carriage-return line', () {
    expect(
      zmodemProgressLine('demo.txt', transferred: 50, total: 200),
      '\r\x1b[Kdemo.txt: 25.0%',
    );
  });

  test('formats unknown-size progress with byte count', () {
    expect(
      zmodemProgressLine('stream.bin', transferred: 128, total: null),
      '\r\x1b[Kstream.bin: 128 bytes',
    );
  });

  test('canceling sz folder picker skips offered file', () async {
    final offer = FakeOffer(
      xterm.ZModemFileInfo(pathname: 'demo.txt', length: 4),
      Stream.value(Uint8List.fromList([1, 2, 3, 4])),
    );
    final terminalText = <String>[];
    final session = RemoteSshZModemSession(
      sessionId: 'session-1',
      stdout: const Stream.empty(),
      writeToSession: (_, __) async {},
      writeTerminal: terminalText.add,
      selectDownloadDirectory: () async => null,
      selectUploadFiles: () async => null,
      logger: const NoopErrorLogger(),
    );

    await session.handleFileOfferForTest(offer);

    expect(offer.skipped, isTrue);
    expect(offer.acceptedOffsets, isEmpty);
    expect(terminalText.join(), contains('Skipped demo.txt'));
    await session.dispose();
  });

  test('sz receive writes basename inside selected directory', () async {
    final dir = await Directory.systemTemp.createTemp('deepssh-zmodem-test-');
    addTearDown(() async => dir.delete(recursive: true));
    final offer = FakeOffer(
      xterm.ZModemFileInfo(pathname: '../demo.txt', length: 4),
      Stream.value(Uint8List.fromList([1, 2, 3, 4])),
    );
    final terminalText = <String>[];
    final session = RemoteSshZModemSession(
      sessionId: 'session-1',
      stdout: const Stream.empty(),
      writeToSession: (_, __) async {},
      writeTerminal: terminalText.add,
      selectDownloadDirectory: () async => dir.path,
      selectUploadFiles: () async => null,
      logger: const NoopErrorLogger(),
    );

    await session.handleFileOfferForTest(offer);

    expect(
      await File(
        '${dir.path}${Platform.pathSeparator}demo.txt',
      ).readAsBytes(),
      [1, 2, 3, 4],
    );
    expect(terminalText.join(), contains('Received demo.txt'));
    await session.dispose();
  });

  test('canceling rz file picker returns no upload offers', () async {
    final session = RemoteSshZModemSession(
      sessionId: 'session-1',
      stdout: const Stream.empty(),
      writeToSession: (_, __) async {},
      writeTerminal: (_) {},
      selectDownloadDirectory: () async => null,
      selectUploadFiles: () async => null,
      logger: const NoopErrorLogger(),
    );

    final offers = await session.handleFileRequestForTest();

    expect(offers, isEmpty);
    await session.dispose();
  });

  test('rz file picker creates upload offers with offset-aware streams', () async {
    final session = RemoteSshZModemSession(
      sessionId: 'session-1',
      stdout: const Stream.empty(),
      writeToSession: (_, __) async {},
      writeTerminal: (_) {},
      selectDownloadDirectory: () async => null,
      selectUploadFiles: () async => [
        ZModemUploadFile(
          name: 'upload.txt',
          size: 4,
          openRead: (offset) => Stream.value(
            Uint8List.fromList([1, 2, 3, 4].skip(offset).toList()),
          ),
        ),
      ],
      logger: const NoopErrorLogger(),
    );

    final offers = (await session.handleFileRequestForTest()).toList();
    final data = await offers.single.accept(2).expand((chunk) => chunk).toList();

    expect(offers.single.info.pathname, 'upload.txt');
    expect(offers.single.info.length, 4);
    expect(data, [3, 4]);
    await session.dispose();
  });

  test('writeTerminalInput routes bytes to SSH through mux normal path', () async {
    final writes = <List<int>>[];
    final session = RemoteSshZModemSession(
      sessionId: 'session-1',
      stdout: const Stream.empty(),
      writeToSession: (_, data) async => writes.add(data),
      writeTerminal: (_) {},
      selectDownloadDirectory: () async => null,
      selectUploadFiles: () async => null,
      logger: const NoopErrorLogger(),
    );
    session.start();

    session.writeTerminalInput('ls\r');
    await Future<void>.delayed(Duration.zero);

    expect(writes, [<int>[108, 115, 13]]);
    await session.dispose();
  });

  test('receive errors are logged and written to terminal', () async {
    final logger = FakeErrorLogger();
    final offer = FakeOffer(
      xterm.ZModemFileInfo(pathname: 'bad.txt', length: 1),
      Stream<Uint8List>.error(StateError('disk failed')),
    );
    final terminalText = <String>[];
    final dir = await Directory.systemTemp.createTemp('deepssh-zmodem-error-');
    addTearDown(() async => dir.delete(recursive: true));
    final session = RemoteSshZModemSession(
      sessionId: 'session-1',
      stdout: const Stream.empty(),
      writeToSession: (_, __) async {},
      writeTerminal: terminalText.add,
      selectDownloadDirectory: () async => dir.path,
      selectUploadFiles: () async => null,
      logger: logger,
    );

    await session.handleFileOfferForTest(offer);

    expect(logger.entries.single.scope, 'zmodem.receive');
    expect(terminalText.join(), contains('ZModem receive failed'));
    await session.dispose();
  });

  test('calls onDone when stdout closes', () async {
    final output = StreamController<List<int>>();
    final done = Completer<void>();
    final session = RemoteSshZModemSession(
      sessionId: 'session-1',
      stdout: output.stream,
      writeToSession: (_, __) async {},
      writeTerminal: (_) {},
      selectDownloadDirectory: () async => null,
      selectUploadFiles: () async => null,
      logger: const NoopErrorLogger(),
      onDone: done.complete,
    );
    session.start();

    await output.close();

    await done.future;
    await session.dispose();
  });

  test('upload file adapter exposes basename and offset stream', () async {
    final dir = await Directory.systemTemp.createTemp('deepssh-upload-adapter-');
    addTearDown(() async => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}upload.txt');
    await file.writeAsBytes([10, 20, 30, 40]);

    final upload = uploadFileFromPath(file.path, size: 4);
    final data = await upload.openRead(1).expand((chunk) => chunk).toList();

    expect(upload.name, 'upload.txt');
    expect(upload.size, 4);
    expect(data, [20, 30, 40]);
  });
}
