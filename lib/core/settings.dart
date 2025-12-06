import 'dart:convert';

import 'package:emotic/core/app_theme.dart';
import 'package:emotic/core/constants.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/entities/semver.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite/sqflite.dart';

class GlobalSettings extends Equatable {
  /// Indicates whether this is the first time the user has used Emotic
  final bool isFirstTime;

  /// If the user has used it before, show the last used version. If it is
  /// null, it should mean it's a first time user.
  final SemVer? lastUsedVersion;

  /// Theme of the app
  final EmoticThemeMode emoticThemeMode;

  /// Size of the emoticons in Emoticons listing page
  final int? emoticonsTextSize;

  /// Size of the pictures in Emotipics listing page
  final int? emotipicsColumnCount;

  /// Size of text in Fancy Text page
  final int? fancyTextSize;

  /// Indicates whether the app has been updated, using [lastUsedVersion]
  bool get isUpdated {
    return (lastUsedVersion == null) ? true : lastUsedVersion! < version;
  }

  /// Indicates whether the settings should be reloaded
  bool get shouldReload {
    return isFirstTime || isUpdated;
  }

  const GlobalSettings({
    required this.isFirstTime,
    required this.lastUsedVersion,
    required this.emoticThemeMode,
    this.emoticonsTextSize,
    this.emotipicsColumnCount,
    this.fancyTextSize,
  });

  @override
  List<Object?> get props => [
        isFirstTime,
        lastUsedVersion,
        emoticThemeMode,
        emoticonsTextSize,
        emotipicsColumnCount,
        fancyTextSize,
      ];
  GlobalSettings copyWith({
    bool? isFirstTime,
    SemVer? lastUsedVersion,
    EmoticThemeMode? emoticThemeMode,
    int? emoticonsTextSize = -1,
    int? emotipicsColumnCount = -1,
    int? fancyTextSize = -1,
  }) {
    // -1 means that arg wasn't supplied, just to differentiate b/w passing null
    return GlobalSettings(
      isFirstTime: isFirstTime ?? this.isFirstTime,
      lastUsedVersion: lastUsedVersion ?? this.lastUsedVersion,
      emoticThemeMode: emoticThemeMode ?? this.emoticThemeMode,
      emoticonsTextSize: switch (emoticonsTextSize) {
        -1 => this.emoticonsTextSize,
        null => null,
        _ => emoticonsTextSize,
      },
      emotipicsColumnCount: switch (emotipicsColumnCount) {
        -1 => this.emotipicsColumnCount,
        null => null,
        _ => emotipicsColumnCount,
      },
      fancyTextSize: switch (fancyTextSize) {
        -1 => this.fancyTextSize,
        null => null,
        _ => fancyTextSize,
      },
    );
  }
}

abstract class GlobalSettingsSource {
  Future<GlobalSettings> getSavedSettings();
  Future<void> saveSettings(GlobalSettings newSettings);
}

class GlobalSettingsSourceSQLite implements GlobalSettingsSource {
  final Database db;
  GlobalSettingsSourceSQLite({required this.db});

  @override
  Future<void> saveSettings(GlobalSettings newSettings) {
    return _saveSettings(
      db: db,
      newSettings: newSettings,
    );
  }

  @override
  Future<GlobalSettings> getSavedSettings() {
    return _getSavedSettings(db: db);
  }

  Future<void> importFromDb({required Database importDb}) async {
    final importSettings = await _getSavedSettings(db: importDb);
    final currentSettings = await getSavedSettings();
    if (importSettings.isFirstTime) {
      // This means that there is no settings table in the importDb, so don't do
      // anything
      return;
    } else {
      return saveSettings(
        GlobalSettings(
          isFirstTime: currentSettings.isFirstTime,
          lastUsedVersion: currentSettings.lastUsedVersion,
          emoticThemeMode: importSettings.emoticThemeMode,
          emoticonsTextSize: importSettings.emoticonsTextSize ??
              currentSettings.emoticonsTextSize,
          emotipicsColumnCount: importSettings.emotipicsColumnCount ??
              currentSettings.emotipicsColumnCount,
          fancyTextSize:
              importSettings.fancyTextSize ?? currentSettings.fancyTextSize,
        ),
      );
    }
  }

  Future<void> exportToDb({required Database exportDb}) async {
    final currentSettings = await getSavedSettings();
    await _ensureTable(db: exportDb);
    return _saveSettings(db: exportDb, newSettings: currentSettings);
  }

  Future<void> _ensureTable({required Database db}) async {
    await db.execute("""
CREATE TABLE IF NOT EXISTS ${_SQLNames.settingsTableName}
  (
    ${_SQLNames.settingsKeyColName} VARCHAR,
    ${_SQLNames.settingsValueColName} VARCHAR
  )
""");
  }

  Map<String, String?> _getSettingsKVFromResult(
      List<Map<String, Object?>> result) {
    return Map.fromEntries(
      result.map(
        (row) {
          return MapEntry(
            row[_SQLNames.settingsKeyColName] as String,
            row[_SQLNames.settingsValueColName] as String?,
          );
        },
      ),
    );
  }

  Future<GlobalSettings> _getSavedSettings({required Database db}) async {
    await _performMigrationForPre0_1_6(db: db);
    await _ensureTable(db: db);
    final settingsResult = await db.rawQuery("""
SELECT 
  ${_SQLNames.settingsKeyColName}, ${_SQLNames.settingsValueColName} 
FROM 
  ${_SQLNames.settingsTableName}
""");
    if (settingsResult.isEmpty) {
      return const GlobalSettings(
        isFirstTime: true,
        lastUsedVersion: null,
        emoticThemeMode: EmoticThemeMode.system,
      );
    } else {
      final settingsKV = _getSettingsKVFromResult(settingsResult);
      final isFirstTime = bool.tryParse(
        settingsKV[_SQLNames.settingsKeyIsFirstTime] ?? "",
      );
      SemVer lastUsedVersion;
      try {
        final lastUsedVersionString =
            settingsKV[_SQLNames.settingsKeylastUsedVersion];
        if (lastUsedVersionString != null) {
          lastUsedVersion = SemVer.fromString(
            lastUsedVersionString,
          );
        } else {
          lastUsedVersion = SemVer.fromString("0.1.10");
        }
      } on ArgumentError {
        lastUsedVersion = SemVer.fromString("0.1.10");
      }

      // From 0.1.11 onwards, [lastUsedVersion] should not be null if the app
      // has been used before. So if it it found to be null in the db, assume
      // 0.1.10 as the [lastUsedVersion]

      final emoticThemeMode = EmoticThemeMode.values.byName(
        settingsKV[_SQLNames.settingsKeyThemeMode]?.toString() ??
            EmoticThemeMode.system.name,
      );
      final emoticonsTextSize =
          int.tryParse(settingsKV[_SQLNames.settingsKeyEmoticonTextSize] ?? "");
      final emotipicsColCount = int.tryParse(
          settingsKV[_SQLNames.settingsKeyEmotipicsColCount] ?? "");
      final fancyTextSize =
          int.tryParse(settingsKV[_SQLNames.settingsKeyFancyTextSize] ?? "");
      final globalSettings = GlobalSettings(
        isFirstTime: isFirstTime ?? true,
        lastUsedVersion: lastUsedVersion,
        emoticThemeMode: emoticThemeMode,
        emoticonsTextSize: emoticonsTextSize,
        emotipicsColumnCount: emotipicsColCount,
        fancyTextSize: fancyTextSize,
      );
      getLogger().fine("Got $globalSettings");
      return globalSettings;
    }
  }

  Future<void> _saveSettings({
    required Database db,
    required GlobalSettings newSettings,
  }) async {
    await _ensureTable(db: db);
    getLogger().config("Going to save $newSettings");

    final settingsRowsToInsert = {
      _SQLNames.settingsKeyIsFirstTime: newSettings.isFirstTime.toString(),
      _SQLNames.settingsKeylastUsedVersion:
          (newSettings.lastUsedVersion ?? version).toString(),
      _SQLNames.settingsKeyThemeMode: newSettings.emoticThemeMode.name,
      _SQLNames.settingsKeyEmoticonTextSize:
          newSettings.emoticonsTextSize.toString(),
      _SQLNames.settingsKeyEmotipicsColCount:
          newSettings.emotipicsColumnCount.toString(),
      _SQLNames.settingsKeyFancyTextSize: newSettings.fancyTextSize.toString(),
    };
    await db.execute("""
DELETE FROM ${_SQLNames.settingsTableName}
""");

    for (final row in settingsRowsToInsert.entries) {
      await db.rawInsert(
        """
        INSERT INTO 
          ${_SQLNames.settingsTableName}
            (${_SQLNames.settingsKeyColName}, ${_SQLNames.settingsValueColName})
        VALUES
          (?, ?)
        """,
        [
          row.key,
          row.value,
        ],
      );
    }
  }

  Future<void> _performMigrationForPre0_1_6({required Database db}) async {
    final String? previousVersionString;

    // First check if the old settings table exists, by trying to create one
    await db.execute("""
CREATE TABLE IF NOT EXISTS settings (placeholder INTEGER)
""");
    final tableAlreadyThereCheckResult = await db.rawQuery("""
SELECT * FROM settings
""");
    if (tableAlreadyThereCheckResult.isNotEmpty) {
      // This means the user is upgrading from 0.1.5 or below, because otherwise
      // this should be empty
      previousVersionString = jsonDecode(tableAlreadyThereCheckResult
          .first["settings_json"] as String)["lastUsedVersion"] as String;
      getLogger().config(
          "Doing migration from version $previousVersionString settings table");
    } else {
      getLogger().config(
        "No rows in settings(old) table, this means that either its a new user "
        "or v0.1.6+ user",
      );
      previousVersionString = null;
    }

    // We're not using that table anymore
    await db.execute("""
DROP TABLE IF EXISTS settings
""");

    if (previousVersionString != null) {
      await _ensureTable(db: db);
      await db.rawInsert(
        """
INSERT INTO ${_SQLNames.settingsTableName}
VALUES
  (?, ?)
      """,
        [
          _SQLNames.settingsKeyIsFirstTime,
          false.toString(),
        ],
      );
      await db.rawInsert(
        """
INSERT INTO ${_SQLNames.settingsTableName}
VALUES
  (?, ?)
      """,
        [
          _SQLNames.settingsKeylastUsedVersion,
          "0.1.5"
        ], // We'll assume it's this version, no change with older one anyway
      );
    }
  }
}

sealed class GlobalSettingsState {
  const GlobalSettingsState();
}

class GlobalSettingsInitial implements GlobalSettingsState {
  const GlobalSettingsInitial();
}

class GlobalSettingsLoading implements GlobalSettingsState {
  const GlobalSettingsLoading();
}

class GlobalSettingsLoaded extends Equatable implements GlobalSettingsState {
  final GlobalSettings settings;
  const GlobalSettingsLoaded({
    required this.settings,
  });
  @override
  List<Object?> get props => [settings];
}

class GlobalSettingsCubit extends Cubit<GlobalSettingsState> {
  final GlobalSettingsSource globalsettingsSource;

  GlobalSettingsCubit({
    required this.globalsettingsSource,
  }) : super(const GlobalSettingsInitial()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    getLogger().fine("Loading saved settings");
    emit(const GlobalSettingsLoading());
    emit(
      GlobalSettingsLoaded(
        settings: await globalsettingsSource.getSavedSettings(),
      ),
    );
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
  }

  Future<void> saveSettings(GlobalSettings newSettings) async {
    getLogger().fine("Saving settings");
    await globalsettingsSource.saveSettings(newSettings);
    emit(GlobalSettingsLoaded(settings: newSettings));
  }

  Future<void> changeEmotipicsColCount({required int? colCount}) async {
    if (state case GlobalSettingsLoaded(:final settings)) {
      if (colCount != null &&
          (colCount < emotipicsColCountLowerLimit ||
              colCount > emotipicsColCountUpperLimit)) {
        return;
      } else {
        await saveSettings(
          settings.copyWith(
            emotipicsColumnCount: colCount,
          ),
        );
      }
    }
  }

  Future<void> changeEmoticonsFontSize({required int? newSize}) async {
    if (state case GlobalSettingsLoaded(:final settings)) {
      if (newSize != null &&
          (newSize < emoticonsTextSizeLowerLimit ||
              newSize > emoticonsTextSizeUpperLimit)) {
        return;
      } else {
        await saveSettings(
          settings.copyWith(
            emoticonsTextSize: newSize,
          ),
        );
      }
    }
  }

  Future<void> changeFancyTextFontSize({required int? newSize}) async {
    if (state case GlobalSettingsLoaded(:final settings)) {
      if (newSize != null &&
          (newSize < fancyTextSizeLowerLimit ||
              newSize > fancyTextSizeUpperLimit)) {
        return;
      } else {
        await saveSettings(
          settings.copyWith(
            fancyTextSize: newSize,
          ),
        );
      }
    }
  }
}

abstract final class _SQLNames {
  static const settingsTableName = "settings_data";
  static const settingsKeyColName = "key";
  static const settingsValueColName = "value";
  static const settingsKeyIsFirstTime = "is_first_time";
  static const settingsKeylastUsedVersion = "last_used_version";
  static const settingsKeyThemeMode = "theme_mode";
  static const settingsKeyEmoticonTextSize = "emoticons_text_size";
  static const settingsKeyEmotipicsColCount = "emotipics_col_count";
  static const settingsKeyFancyTextSize = "fancy_text_size";
}
