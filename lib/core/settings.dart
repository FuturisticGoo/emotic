import 'dart:convert';

import 'package:emotic/core/app_theme.dart';
import 'package:emotic/core/constants.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/entities/semver.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite/sqflite.dart';

class GlobalSettings extends Equatable {
  final bool isFirstTime;
  final SemVer? lastUsedVersion;
  final EmoticThemeMode emoticThemeMode;
  final int? emoticonsTextSize;
  final int? emotipicsColumnCount;
  final int? fancyTextSize;
  bool get isUpdated {
    return (lastUsedVersion == null) ? true : lastUsedVersion! < version;
  }

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
  Future<void> _ensureTable() async {
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

  @override
  Future<GlobalSettings> getSavedSettings() async {
    await _performMigrationForPre0_1_6();
    await _ensureTable();
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
      SemVer? lastUsedVersion;
      try {
        final lastUsedVersionString =
            settingsKV[_SQLNames.settingsKeylastUsedVersion];
        if (lastUsedVersionString != null) {
          lastUsedVersion = SemVer.fromString(
            lastUsedVersionString,
          );
        } else {
          lastUsedVersion = null;
        }
      } on ArgumentError {
        lastUsedVersion = null;
      }

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

  @override
  Future<void> saveSettings(GlobalSettings newSettings) async {
    await _ensureTable();
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

  Future<void> _performMigrationForPre0_1_6() async {
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
      await _ensureTable();
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
