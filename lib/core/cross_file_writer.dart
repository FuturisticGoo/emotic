import 'dart:io';
import 'package:emotic/core/helper_functions.dart';
import 'package:emotic/core/entities/status_entities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pick_or_save/pick_or_save.dart';

abstract class CrossFileWriter {
  Future<void> writeBytes({required Uint8List bytes});
  Future<void> close();
  const CrossFileWriter();
  static Future<CrossFileWriter> openFileForWriting({
    required String fileName,
    required EmoticAppDataDirectory emoticAppDataDirectory,
  }) async {
    if (Platform.isAndroid) {
      return AndroidFileWriter.openFileForWriting(
        fileName: fileName,
        emoticAppDataDirectory: emoticAppDataDirectory,
      );
    } else if (Platform.isLinux || Platform.isWindows) {
      return DesktopFileWriter.openFileForWriting(fileName: fileName);
    } else {
      throw UnsupportedError("Apple devices not supported");
    }
  }
}

class DesktopFileWriter implements CrossFileWriter {
  final IOSink ioSink;
  const DesktopFileWriter({
    required this.ioSink,
  });

  static Future<DesktopFileWriter> openFileForWriting({
    required String fileName,
  }) async {
    final filePath = await FilePicker.platform.saveFile(fileName: fileName);
    if (filePath == null) {
      throw NoSaveFilePickedException();
    } else {
      final ioSink = File(filePath).openWrite(mode: FileMode.writeOnly);
      return DesktopFileWriter(ioSink: ioSink);
    }
  }

  @override
  Future<void> writeBytes({required Uint8List bytes}) async {
    ioSink.add(bytes);
  }

  @override
  Future<void> close() async {
    await ioSink.flush();
    await ioSink.close();
  }
}

class AndroidFileWriter implements CrossFileWriter {
  final File cacheOutputFile;
  final IOSink ioSink;
  const AndroidFileWriter({
    required this.cacheOutputFile,
    required this.ioSink,
  });

  static Future<AndroidFileWriter> openFileForWriting({
    required String fileName,
    required EmoticAppDataDirectory emoticAppDataDirectory,
  }) async {
    final cachePath = await emoticAppDataDirectory.getAppCacheDir();
    final cacheOutputFile = File(p.join(cachePath, fileName));
    final ioSink = cacheOutputFile.openWrite(
      mode: FileMode.writeOnly,
    );
    return AndroidFileWriter(
      cacheOutputFile: cacheOutputFile,
      ioSink: ioSink,
    );
  }

  @override
  Future<void> writeBytes({required Uint8List bytes}) async {
    ioSink.add(bytes);
  }

  @override
  Future<void> close() async {
    await ioSink.flush();
    await ioSink.close();
    final result = await PickOrSave().fileSaver(
      params: FileSaverParams(
        saveFiles: [
          SaveFileInfo(
            filePath: cacheOutputFile.path,
            fileName: p.basename(
              cacheOutputFile.path,
            ),
          ),
        ],
      ),
    );
    await cacheOutputFile.delete();
    if (result == null) {
      throw NoSaveFilePickedException();
    }
  }
}
