import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import 'ssh_zmodem_session.dart';

bool _entitlementsSkipped = false;

/// On macOS, file_picker checks for User Selected File entitlements even when
/// App Sandbox is disabled. Calling [FilePicker.skipEntitlementsChecks] tells
/// the plugin to skip that check so the native file/folder picker can open.
Future<void> _ensureEntitlementsSkipped() async {
  if (_entitlementsSkipped) return;
  if (Platform.isMacOS) {
    await FilePicker.skipEntitlementsChecks();
  }
  _entitlementsSkipped = true;
}

Future<String?> selectZModemDownloadDirectory() async {
  await _ensureEntitlementsSkipped();
  return FilePicker.getDirectoryPath();
}

Future<List<ZModemUploadFile>?> selectZModemUploadFiles() async {
  await _ensureEntitlementsSkipped();
  final result = await FilePicker.pickFiles(
    allowMultiple: true,
    withReadStream: true,
  );
  if (result == null) return null;

  final files = <ZModemUploadFile>[];
  for (final file in result.files) {
    final filePath = file.path;
    if (filePath == null) continue;
    files.add(uploadFileFromPath(filePath, size: file.size));
  }
  return files;
}

ZModemUploadFile uploadFileFromPath(String filePath, {required int size}) {
  return ZModemUploadFile(
    name: path.basename(filePath),
    size: size,
    openRead: (offset) => File(
      filePath,
    ).openRead(offset).map((chunk) => Uint8List.fromList(chunk)),
  );
}
