import 'package:emotic/core/settings.dart';
import 'package:emotic/data/emoticons_repository.dart';
import 'package:emotic/data/emoticons_source.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';
import 'package:get_it/get_it.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

final sl = GetIt.instance;

Future<void> initSetup() async {
  final docDir = await getApplicationDocumentsDirectory();
  final db = sqlite3.open(p.join(docDir.path, sqldbName));
  sl.registerSingleton<Database>(
    db,
    dispose: (param) {
      param.dispose();
    },
  );
  sl.registerSingleton<SettingsSource>(SettingsSourceDb(db: db));

  const assetSource = "assetBundle";
  const dbSource = "dbSource";

  sl.registerSingleton<EmoticonsSource>(
    EmoticonsSourceAssetBundle(
      assetBundle: rootBundle,
    ),
    instanceName: assetSource,
  );
  sl.registerSingleton<EmoticonsSource>(
    EmoticonsSqliteSource(db: db),
    instanceName: dbSource,
    dispose: (param) {
      (param as EmoticonsSqliteSource).dispose();
    },
  );
  sl.registerSingleton<EmoticonsRepository>(
    EmoticonsRepository(
      assetSource: sl(
        instanceName: assetSource,
      ),
      database: sl(instanceName: dbSource),
    ),
  );
}
