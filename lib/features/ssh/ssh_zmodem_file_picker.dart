import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import 'ssh_zmodem_session.dart';

Future<String?> selectZModemDownloadDirectory() {
  return FilePicker.getDirectoryPath();
}

Future<List<ZModemUploadFile>?> selectZModemUploadFiles() async {
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
