import 'dart:io';
import 'dart:typed_data';

import 'package:emotic/core/constants.dart';
import 'package:emotic/core/cross_file_writer.dart' as hf;
import 'package:emotic/core/global_progress_pipe.dart';
import 'package:emotic/core/import_export_writer.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/status_entities.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:emotic/core/helper_functions.dart' as hf;
import 'package:path/path.dart' as p;

final class ImportBundle {
  final Database db;
  final ImportReader importReader;
  final Future<void> Function() onImportFinish;
  const ImportBundle({
    required this.db,
    required this.importReader,
    required this.onImportFinish,
  });
}

final class ExportBundle {
  final Database db;
  final ExportWriter exportWriter;
  final Future<void> Function() finishExport;
  const ExportBundle({
    required this.db,
    required this.exportWriter,
    required this.finishExport,
  });
}

abstract class SettingsSource {
  Future<ImportBundle> importFromFile();
  Future<ExportBundle> exportToFile();
}

class SettingsSourceImpl implements SettingsSource {
  final hf.EmoticAppDataDirectory emoticAppDataDirectory;
  final GlobalProgressPipe globalProgressPipe;
  const SettingsSourceImpl({
    required this.emoticAppDataDirectory,
    required this.globalProgressPipe,
  });
  @override
  Future<ImportBundle> importFromFile() async {
    final importFile = await hf.pickImportFile();
    if (importFile == null) {
      throw NoImportFilePickedException();
    }

    try {
      // Try using tar reader first, its the new export file format
      getLogger().info("Trying to open file as tar.gz");
      final importFileStream = hf.getFileStreamFromUri(uri: importFile);
      final tarImportReader = await TarImportReader.extractTar(
        inputTarFileStream: importFileStream.map(
          (event) => event.toList(),
        ),
        emoticAppDataDirectory: emoticAppDataDirectory,
        globalProgressPipe: globalProgressPipe,
      );
      final dbPath = await tarImportReader.getDatabasePath();
      final db = await openDatabase(dbPath.toFilePath());
      getLogger().info("Opening extracted database at ${db.path}");

      return ImportBundle(
        db: db,
        importReader: tarImportReader,
        onImportFinish: () async {
          getLogger().info("Closing extracted database and deleting cache");
          await db.close();
          await File.fromUri(dbPath).delete();
        },
      );
    } catch (error, stackTrace) {
      getLogger().warning(
        "Opening import file as tar.gz failed.",
        error,
        stackTrace,
      );
    }

    try {
      // Old/Emoticons only version, still supported
      getLogger().info("Trying to open file as sqlite");
      final importFileStream = hf.getFileStreamFromUri(uri: importFile);
      final cachePath = await emoticAppDataDirectory.getAppCacheDir();
      final cachedDbFile = File(p.join(cachePath, exportImportDbFileName));
      if (await cachedDbFile.exists()) {
        await cachedDbFile.delete();
      }
      final cacheDbFileStream =
          cachedDbFile.openWrite(mode: FileMode.writeOnly);
      await for (final fileBytes in importFileStream) {
        cacheDbFileStream.add(fileBytes);
      }
      await cacheDbFileStream.flush();
      await cacheDbFileStream.close();
      final db = await openDatabase(cachedDbFile.path);
      final appMediaDir = await emoticAppDataDirectory.getAppMediaDir();

      return ImportBundle(
        db: db,
        importReader: TarImportReader(
          dbPath: cachedDbFile.path,
          appMediaPath: appMediaDir,
        ),
        onImportFinish: () async {
          getLogger().info("Closing extracted database and deleting cache");
          await db.close();
          await cachedDbFile.delete();
        },
      );
    } catch (error, stackTrace) {
      getLogger().warning(
        "Opening import file as sqlite failed",
        error,
        stackTrace,
      );
      getLogger().severe(
        "Trying to open import  Unrecognized import file format: $importFile",
      );
      throw UnrecognizedImportFileException();
    }
  }

  @override
  Future<ExportBundle> exportToFile() async {
    final today = DateTime.now();
    final outputFileName = "Emotic_${today.year}_${today.month}_${today.day}"
        "_${today.hour}_${today.minute}.tar.gz";
    final outputCrossFileWriter = await hf.CrossFileWriter.openFileForWriting(
      fileName: outputFileName,
      emoticAppDataDirectory: emoticAppDataDirectory,
    );
    final cachePath = await emoticAppDataDirectory.getAppCacheDir();
    final cachedDbFile = File(p.join(cachePath, exportImportDbFileName));
    final db = await openDatabase(cachedDbFile.path);
    await hf.createMetadataTable(db: db);
    await hf.prefillMetadata(db: db);
    final tarExportWriter = TarExportWriter(
      onBytes: (bytes) async {
        await outputCrossFileWriter.writeBytes(bytes: bytes);
      },
      onFinish: () async {
        await outputCrossFileWriter.close();
      },
    );
    return ExportBundle(
      db: db,
      exportWriter: tarExportWriter,
      finishExport: () async {
        await db.close();
        await tarExportWriter.writeDb(
          fileStream: cachedDbFile.openRead().map(
                (event) => Uint8List.fromList(event),
              ),
          fileName: exportImportDbFileName,
        );
        await tarExportWriter.finishWriting();
        await cachedDbFile.delete();
      },
    );
  }
}
