import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:xterm/xterm.dart' as xterm;

import '../../core/logging/app_logger.dart';

typedef SshSessionWriter = Future<void> Function(
  String sessionId,
  List<int> data,
);
typedef TerminalTextWriter = void Function(String text);
typedef DownloadDirectoryPicker = Future<String?> Function();
typedef UploadFilePicker = Future<List<ZModemUploadFile>?> Function();

abstract interface class SshZModemBinding {
  void writeTerminalInput(String data);
  Future<void> dispose();
}

typedef SshZModemBindingFactory = SshZModemBinding Function({
  required String sessionId,
  required Stream<List<int>> stdout,
  required ValueChanged<String> writeTerminal,
  required VoidCallback onDone,
});

class ZModemUploadFile {
  const ZModemUploadFile({
    required this.name,
    required this.size,
    required this.openRead,
  });

  final String name;
  final int size;
  final Stream<Uint8List> Function(int offset) openRead;
}

String zmodemProgressLine(
  String name, {
  required int transferred,
  required int? total,
}) {
  if (total != null && total > 0) {
    return '\r\x1b[K$name: ${(transferred / total * 100).toStringAsFixed(1)}%';
  }
  return '\r\x1b[K$name: $transferred bytes';
}

class RemoteSshZModemSession implements SshZModemBinding {
  RemoteSshZModemSession({
    required this.sessionId,
    required Stream<List<int>> stdout,
    required this.writeToSession,
    required this.writeTerminal,
    required this.selectDownloadDirectory,
    required this.selectUploadFiles,
    required this.logger,
    this.onDone,
  }) {
    _stdout = stdout.map((chunk) => Uint8List.fromList(chunk)).transform(
      StreamTransformer.fromHandlers(
        handleDone: (sink) {
          onDone?.call();
          sink.close();
        },
      ),
    );
  }

  final String sessionId;
  final SshSessionWriter writeToSession;
  final TerminalTextWriter writeTerminal;
  final DownloadDirectoryPicker selectDownloadDirectory;
  final UploadFilePicker selectUploadFiles;
  final ErrorLogger logger;
  final VoidCallback? onDone;
  late final Stream<Uint8List> _stdout;
  final _stdin = StreamController<List<int>>();
  StreamSubscription<List<int>>? _stdinSubscription;
  xterm.ZModemMux? _mux;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _stdinSubscription = _stdin.stream.listen((data) {
      unawaited(writeToSession(sessionId, data));
    });
    _mux = xterm.ZModemMux(stdin: _stdin.sink, stdout: _stdout)
      ..onTerminalInput = writeTerminal
      ..onFileOffer = (offer) {
        unawaited(_handleFileOffer(offer));
      }
      ..onFileRequest = _handleFileRequest;
  }

  @override
  void writeTerminalInput(String input) {
    _mux?.terminalWrite(input);
  }

  @override
  Future<void> dispose() async {
    final subscription = _stdinSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    unawaited(_stdin.close());
  }

  Future<void> handleFileOfferForTest(xterm.ZModemOffer offer) {
    return _handleFileOffer(offer);
  }

  Future<Iterable<xterm.ZModemOffer>> handleFileRequestForTest() {
    return _handleFileRequest();
  }

  Future<void> _handleFileOffer(xterm.ZModemOffer offer) async {
    final fileName = _safeFileName(offer.info.pathname);
    final outputDir = await selectDownloadDirectory();
    if (outputDir == null) {
      offer.skip();
      writeTerminal('\r\nSkipped $fileName');
      return;
    }

    try {
      var received = 0;
      final file = File(path.join(outputDir, fileName));
      await offer
          .accept(0)
          .map((chunk) {
            received += chunk.length;
            writeTerminal(
              zmodemProgressLine(
                fileName,
                transferred: received,
                total: offer.info.length,
              ),
            );
            return chunk;
          })
          .cast<List<int>>()
          .pipe(file.openWrite());
      writeTerminal('\r\nReceived $fileName');
    } catch (error, stackTrace) {
      await logger.error('zmodem.receive', error, stackTrace);
      writeTerminal('\r\nZModem receive failed: $error');
    }
  }

  Future<Iterable<xterm.ZModemOffer>> _handleFileRequest() async {
    final files = await selectUploadFiles();
    if (files == null || files.isEmpty) {
      return const <xterm.ZModemOffer>[];
    }

    return files.map((file) {
      var sent = 0;
      return xterm.ZModemCallbackOffer(
        xterm.ZModemFileInfo(
          pathname: path.basename(file.name),
          length: file.size,
          mode: '100644',
          filesRemaining: files.length,
          bytesRemaining: file.size,
        ),
        onAccept: (offset) => file.openRead(offset).map((chunk) {
          sent += chunk.length;
          writeTerminal(
            zmodemProgressLine(
              file.name,
              transferred: sent + offset,
              total: file.size,
            ),
          );
          return chunk;
        }),
        onSkip: () {
          writeTerminal('\r\nRejected ${file.name}');
        },
      );
    }).toList(growable: false);
  }

  String _safeFileName(String? pathname) {
    final baseName = path.basename(pathname ?? '').trim();
    return baseName.isEmpty || baseName == '.' ? 'download' : baseName;
  }
}
