import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:emotic/core/constants.dart';
import 'package:emotic/core/global_progress_pipe.dart';
import 'package:emotic/core/helper_functions.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/status_entities.dart';
import 'package:tar/tar.dart';
import 'package:path/path.dart' as p;

abstract class ExportWriter {
  Future<Uri> writeImage({
    required Stream<Uint8List> fileStream,
    required String fileName,
  });
  Future<Uri> writeDb({
    required Stream<Uint8List> fileStream,
    required String fileName,
  });
  Future<void> finishWriting();
}

abstract class ImportReader {
  Future<Uri> getDatabasePath();
  Future<Uri> getAbsoluteImageUri({
    required Uri relativeImageUri,
  });
}

class TarExportWriter implements ExportWriter {
  final Future<void> Function(Uint8List bytes) onBytes;
  final Future<void> Function() onFinish;
  final StreamController<TarEntry> _tarEntryStream = StreamController();
  final _tarWritingCompleter = Completer();
  Future<void> dipose() async {
    await _tarEntryStream.close();
  }

  TarExportWriter({
    required this.onBytes,
    required this.onFinish,
  }) {
    _tarEntryStream.stream
        .transform(
          tarWriter,
        )
        .transform(
          gzip.encoder,
        )
        .forEach(
      (element) async {
        await onBytes(Uint8List.fromList(element));
      },
    ).whenComplete(
      () {
        _tarWritingCompleter.complete();
      },
    );
  }
  @override
  Future<void> finishWriting() async {
    await _tarEntryStream.sink.close();
    await _tarWritingCompleter.future;
    await onFinish();
  }

  @override
  Future<Uri> writeImage({
    required Stream<Uint8List> fileStream,
    required String fileName,
  }) async {
    final relativeUri = Uri(
      scheme: "emotic",
      pathSegments: [
        mediaFolderName,
        imagesFolderName,
        fileName,
      ],
    );
    final tarEntry = TarEntry(
      TarHeader(
        name: relativeUri.path,
        typeFlag: TypeFlag.reg,
        mode: int.parse('644', radix: 8),
      ),
      fileStream,
    );
    _tarEntryStream.sink.add(tarEntry);

    return relativeUri;
  }

  @override
  Future<Uri> writeDb({
    required Stream<Uint8List> fileStream,
    required String fileName,
  }) async {
    final relativeUri = Uri(
      scheme: "emotic",
      pathSegments: [
        fileName,
      ],
    );
    final tarEntry = TarEntry(
      TarHeader(
        name: relativeUri.path,
        typeFlag: TypeFlag.reg,
        mode: int.parse('644', radix: 8),
      ),
      fileStream,
    );
    _tarEntryStream.sink.add(tarEntry);
    return relativeUri;
  }
}

class TarImportReader implements ImportReader {
  final String dbPath;
  final String appMediaPath;
  const TarImportReader({
    required this.dbPath,
    required this.appMediaPath,
  });

  static Future<TarImportReader> extractTar({
    required Stream<List<int>> inputTarFileStream,
    required EmoticAppDataDirectory emoticAppDataDirectory,
    GlobalProgressPipe? globalProgressPipe,
  }) async {
    final tarReader = TarReader(
      inputTarFileStream.transform(gzip.decoder),
    );
    final cacheDir = await emoticAppDataDirectory.getAppCacheDir();
    final imageDir = await emoticAppDataDirectory.imagePath;
    String? dbPath;
    final appMediaPath = await emoticAppDataDirectory.getAppMediaDir();
    int count = 1;
    while (await tarReader.moveNext()) {
      final current = tarReader.current;
      if (current.type == TypeFlag.reg) {
        if (current.name == exportImportDbFileName) {
          globalProgressPipe?.addProgress(
            progressEvent: FileExtractionProgressUpdate(
              finishedFiles: count,
              totalFiles: null,
              message: "Extracting database ${current.name}",
            ),
          );
          count++;
          getLogger().info("Extracting database file: ${current.name}");
          final dbFile = File(p.join(cacheDir, exportImportDbFileName));
          final dbFileStream = dbFile.openWrite(
            mode: FileMode.writeOnly,
          );
          await dbFileStream.addStream(current.contents);
          await dbFileStream.flush();
          await dbFileStream.close();
          dbPath = dbFile.path;
        } else if (current.name
            .startsWith(p.posix.join(mediaFolderName, imagesFolderName))) {
          globalProgressPipe?.addProgress(
            progressEvent: FileExtractionProgressUpdate(
              finishedFiles: count,
              totalFiles: null,
              message: "Extracting image ${current.name}",
            ),
          );
          count++;
          getLogger().info("Extracting image file: ${current.name}");
          final fileName = p.basename(current.name);
          final imageFileStream = File(p.join(imageDir, fileName)).openWrite(
            mode: FileMode.writeOnly,
          );
          await imageFileStream.addStream(current.contents);
          await imageFileStream.flush();
          await imageFileStream.close();
        } else {
          getLogger()
              .warning("Unknown entry in import tar file ${current.name}");
          continue;
        }
      }
    }
    globalProgressPipe?.addProgress(
        progressEvent: FileExtractionProgressFinished());
    if (dbPath == null) {
      throw EmoticDatabaseNotFoundException();
    } else {
      return TarImportReader(
        dbPath: dbPath,
        appMediaPath: appMediaPath,
      );
    }
  }

  @override
  Future<Uri> getAbsoluteImageUri({required Uri relativeImageUri}) async {
    final imageFileName = p.basename(relativeImageUri.path);
    final imagePath = p.join(
      appMediaPath,
      imagesFolderName,
      imageFileName,
    );
    return Uri.file(imagePath);
  }

  @override
  Future<Uri> getDatabasePath() async {
    return Uri.file(dbPath);
  }
}
