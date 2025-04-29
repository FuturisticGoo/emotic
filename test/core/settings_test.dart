import 'package:emotic/core/app_theme.dart';
import 'package:emotic/core/constants.dart';
import 'package:emotic/core/settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

Future<void> main() async {
  group('SettingsSource in SQLite', () {
    late Database db;
    setUp(
      () async {
        databaseFactory = databaseFactoryFfi;
        db = await openDatabase(inMemoryDatabasePath);
      },
    );
    tearDown(
      () async {
        await db.close();
      },
    );
    test('New user settings', () async {
      final settingsSource = SettingsSourceSQLite(db: db);
      final settings = await settingsSource.getSavedSettings();
      expect(
        settings.isFirstTime && settings.lastUsedVersion == null,
        isTrue,
      );
    });

    test('Saving and retrieving settings', () async {
      final settingsSource = SettingsSourceSQLite(db: db);
      final trialSettings = GlobalSettings(
        isFirstTime: false,
        lastUsedVersion: version,
        emoticThemeMode: EmoticThemeMode.system,
      );
      await settingsSource.saveSettings(trialSettings);
      expect(await settingsSource.getSavedSettings(), trialSettings);
    });
  });
}
