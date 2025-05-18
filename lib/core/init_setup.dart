import 'dart:io';

import 'package:emotic/core/logging.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/data/emoticons_repository.dart';
import 'package:emotic/data/emoticons_source.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'constants.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'helper_functions.dart';

final sl = GetIt.instance;

Future<void> initSetup() async {
  await initLogger();

  sl.registerSingleton<EmoticAppDataDirectory>(
    EmoticAppDataDirectoryImpl(),
  );

  await _performPreV0_1_8DataMigration();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
  }

  databaseFactory = databaseFactoryFfi;

  final appDir = await sl<EmoticAppDataDirectory>().getAppDataDir();
  final dbPath = p.join(appDir, sqldbName);
  getLogger().fine("Opening database at $dbPath");
  final db = await openDatabase(dbPath);

  sl.registerSingleton<Database>(
    db,
    dispose: (param) async {
      await param.close();
    },
  );
  sl.registerSingleton<SettingsSource>(
    SettingsSourceSQLite(
      db: db,
    ),
  );

  const assetSource = "assetBundle";
  const dbSource = "dbSource";

  sl.registerSingleton<EmoticonsSource>(
    EmoticonsSourceAssetDB(
      assetBundle: rootBundle,
      emoticAppDataDirectory: sl(),
    ),
    instanceName: assetSource,
    dispose: (sourceDb) async {
      if (sourceDb is EmoticonsSourceAssetDB) {
        await sourceDb.dispose();
      }
    },
  );
  sl.registerSingleton<EmoticonsStore>(
    EmoticonsSqliteSource(
      db: db,
      emoticAppDataDirectory: sl(),
    ),
    instanceName: dbSource,
  );
  sl.registerSingleton<EmoticonsRepository>(
    EmoticonsRepository(
      assetSource: sl(
        instanceName: assetSource,
      ),
      database: sl(
        instanceName: dbSource,
      ),
    ),
  );
}

/// Pre v0.1.8, data used to be stored at the directory returned by
/// [getApplicationDocumentsDirectory], which was kinda ok in Android (not the
/// best still because it was using app_flutter directory instead of the files
/// directory) but on desktop Linux (and probably Windows), it returned the
/// home/documents directory, which isn't ideal. So in v0.1.8, I'm gonna
/// migrate to using [EmoticAppDataDirectory.getAppDataDir] from
/// helper_functions, which uses [getApplicationSupportDirectory] instead
Future<void> _performPreV0_1_8DataMigration() async {
  final docDir = await pp.getApplicationDocumentsDirectory();
  final oldDbPath = p.join(docDir.path, sqldbName);
  // If this file exists, it means its pre v0.1.8
  if (await File(oldDbPath).exists()) {
    getLogger().config(
        "db found in old app data directory, this means user is pre v0.1.8");
    final appDir = await sl<EmoticAppDataDirectory>().getAppDataDir();
    final correctDbPath = p.join(appDir, sqldbName);
    if (!(await File(correctDbPath).exists())) {
      await File(oldDbPath).copy(correctDbPath);
    }
    await File(oldDbPath).delete();
    final oldSourceDbPath = p.join(docDir.path, emoticonsSourceDbName);
    if (await File(oldSourceDbPath).exists()) {
      await File(oldSourceDbPath).delete();
    }
  }
}
