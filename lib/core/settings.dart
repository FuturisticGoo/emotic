import 'dart:convert';

import 'package:emotic/core/constants.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/semver.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite/sqflite.dart';

class GlobalSettings extends Equatable {
  final bool isFirstTime;
  final SemVer lastUsedVersion;
  bool get isUpdated {
    return lastUsedVersion < version;
  }

  bool get shouldReload {
    return isFirstTime || isUpdated;
  }

  const GlobalSettings({
    required this.isFirstTime,
    required this.lastUsedVersion,
  });

  @override
  List<Object?> get props => [
        isFirstTime,
        lastUsedVersion,
      ];
}

abstract class SettingsSource {
  Future<GlobalSettings> getSavedSettings();
  Future<void> saveSettings(GlobalSettings newSettings);
}

class SettingsSourceSQLite implements SettingsSource {
  final Database db;
  SettingsSourceSQLite({required this.db});
  Future<void> _ensureTable() async {
    await db.execute("""
CREATE TABLE IF NOT EXISTS $sqldbSettingsTableName
  (
    $sqldbSettingsKeyColName VARCHAR,
    $sqldbSettingsValueColName VARCHAR
  )
""");
  }

  Map<String, String> _getSettingsKVFromResult(
      List<Map<String, Object?>> result) {
    return Map.fromEntries(
      result.map(
        (row) {
          return MapEntry(
            row[sqldbSettingsKeyColName] as String,
            row[sqldbSettingsValueColName] as String,
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
  $sqldbSettingsKeyColName, $sqldbSettingsValueColName 
FROM 
  $sqldbSettingsTableName
""");
    if (settingsResult.isEmpty) {
      return const GlobalSettings(
        isFirstTime: true,
        lastUsedVersion: version,
      );
    } else {
      final settingsKV = _getSettingsKVFromResult(settingsResult);
      final isFirstTime = bool.tryParse(
        settingsKV[sqldbSettingsKeyIsFirstTime] ?? "",
      );
      SemVer lastUsedVersion;
      try {
        final lastUsedVersionString =
            settingsKV[sqldbSettingsKeylastUsedVersion] ?? version.toString();
        lastUsedVersion = SemVer.fromString(
          lastUsedVersionString,
        );
      } on ArgumentError {
        lastUsedVersion = version;
      }
      final globalSettings = GlobalSettings(
        isFirstTime: isFirstTime ?? true,
        lastUsedVersion: lastUsedVersion,
      );
      getLogger().fine("Got $globalSettings");
      return globalSettings;
    }
  }

  @override
  Future<void> saveSettings(GlobalSettings newSettings) async {
    await _ensureTable();
    getLogger().config("Going to save $newSettings");
    await db.execute("""
DELETE FROM $sqldbSettingsTableName
""");

    await db.rawInsert(
      """
INSERT INTO 
  $sqldbSettingsTableName
    ($sqldbSettingsKeyColName, $sqldbSettingsValueColName)
VALUES
  (?, ?)
""",
      [
        sqldbSettingsKeyIsFirstTime,
        newSettings.isFirstTime.toString(),
      ],
    );

    await db.rawInsert(
      """
INSERT INTO 
  $sqldbSettingsTableName
    ($sqldbSettingsKeyColName, $sqldbSettingsValueColName)
VALUES
  (?, ?)
""",
      [
        sqldbSettingsKeylastUsedVersion,
        newSettings.lastUsedVersion.toString(),
      ],
    );
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
INSERT INTO $sqldbSettingsTableName
VALUES
  (?, ?)
      """,
        [sqldbSettingsKeyIsFirstTime, false.toString()],
      );
      await db.rawInsert(
        """
INSERT INTO $sqldbSettingsTableName
VALUES
  (?, ?)
      """,
        [
          sqldbSettingsKeylastUsedVersion,
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
  final SettingsSource settingsSource;

  GlobalSettingsCubit({
    required this.settingsSource,
  }) : super(const GlobalSettingsInitial()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    getLogger().fine("Loading saved settings");
    emit(const GlobalSettingsLoading());
    emit(
      GlobalSettingsLoaded(
        settings: await settingsSource.getSavedSettings(),
      ),
    );
  }

  Future<void> refreshSettings() async {
    getLogger().fine("Refreshing settings");
    await _loadSettings();
  }

  Future<void> saveSettings(GlobalSettings newSettings) async {
    getLogger().fine("Saving settings");
    await settingsSource.saveSettings(newSettings);
  }
}
