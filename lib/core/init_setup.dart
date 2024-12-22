import 'dart:io';

import 'package:emotic/core/settings.dart';
import 'package:emotic/data/emoticons_repository.dart';
import 'package:emotic/data/emoticons_source.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final sl = GetIt.instance;

Future<void> initSetup() async {
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
  }
  // Change the default factory. On iOS/Android, if not using `sqlite_flutter_lib` you can forget
  // this step, it will use the sqlite version available on the system.
  databaseFactory = databaseFactoryFfi;
  final docDir = await getApplicationDocumentsDirectory();

  final db = await openDatabase(p.join(docDir.path, sqldbName));
  sl.registerSingleton<Database>(
    db,
    dispose: (param) async {
      await param.close();
    },
  );
  sl.registerSingleton<SettingsSource>(SettingsSourceDb(db: db));

  const assetSource = "assetBundle";
  const dbSource = "dbSource";

  sl.registerSingleton<EmoticonsSource>(
    EmoticonsSourceAssetDB(
      assetBundle: rootBundle,
    ),
    instanceName: assetSource,
    dispose: (sourceDb) async {
      if (sourceDb is EmoticonsSourceAssetDB) {
        await sourceDb.dispose();
      }
    },
  );
  sl.registerSingleton<EmoticonsStore>(
    EmoticonsSqliteSource(db: db),
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
