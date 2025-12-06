import 'package:emotic/core/constants.dart';
import 'package:emotic/core/helper_functions.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/entities/semver.dart';
import 'package:emotic/data/emoticons_source.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'init_setup.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as p;

Future<void> loadEmoticonsFromSourceDB({
  SemVer? filterVersion,
}) async {
  final EmoticonsSource emoticonsSource = sl();
  final EmoticAppDataDirectory emoticAppDataDirectory = sl();
  final sourceDbFile = await rootBundle.load(emoticonsSourceDbAsset);
  final appDataPath = await emoticAppDataDirectory.getAppDataDir();
  final dbFile = io.File(p.join(appDataPath, emoticonsSourceDbName));
  await dbFile.writeAsBytes(sourceDbFile.buffer.asUint8List(), flush: true);
  final sourceDb = await openDatabase(dbFile.path);
  final dbVersion = await getMetadataVersion(db: sourceDb);
  if (emoticonsSource is EmoticonsSqliteSource) {
    await emoticonsSource.importFromDb(
      importDb: sourceDb,
      importStrategy: ImportStrategy.merge,
      filterVersion: filterVersion,
      dbVersion: dbVersion,
    );
  }
  await sourceDb.close();
  await dbFile.delete();
}

Future<void> performAppUpdateOperations({
  required SemVer? lastUsedVersion,
  required SemVer currentRunningVersion,
}) async {
  getLogger().config(
      "Performing app update operations from $lastUsedVersion to $currentRunningVersion");
  final emoticonsSource = sl<EmoticonsSource>();
  if (emoticonsSource is EmoticonsSqliteSource) {
    await emoticonsSource.ensureAndUpdateSchema(
      db: sl(),
      dbPreviousVersion: lastUsedVersion,
      currentVersion: currentRunningVersion,
    );
  }

  await loadEmoticonsFromSourceDB(
    filterVersion: (lastUsedVersion == null)
        ? null // Load everything if it's a new user
        : version, // Only load the new emoticons if app update
  );
}
