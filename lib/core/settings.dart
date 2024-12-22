import 'dart:convert';

import 'package:emotic/core/constants.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sqflite/sqflite.dart';
part 'settings.g.dart';

@JsonSerializable()
class GlobalSettings extends Equatable {
  final bool isFirstTime;
  final String lastUsedVersion;
  bool get isUpdated {
    return lastUsedVersion != version;
  }

  bool get shouldReload {
    return isFirstTime || isUpdated;
  }

  const GlobalSettings({
    required this.isFirstTime,
    required this.lastUsedVersion,
  });
  Map<String, dynamic> toJson() => _$GlobalSettingsToJson(this);
  factory GlobalSettings.fromJson(Map<String, dynamic> json) =>
      _$GlobalSettingsFromJson(json);
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

class SettingsSourceDb implements SettingsSource {
  final Database db;
  SettingsSourceDb({required this.db});
  Future<void> _ensureTable() async {
    await db.execute("""
CREATE TABLE IF NOT EXISTS $sqldbSettingsTableName
  (
    $sqldbSettingsId INTEGER,
    $sqldbSettingsJson VARCHAR
  )
""");
  }

  @override
  Future<GlobalSettings> getSavedSettings() async {
    await _ensureTable();
    final settingsResult = await db.rawQuery("""
SELECT $sqldbSettingsJson FROM $sqldbSettingsTableName
WHERE $sqldbSettingsId==$sqldbSettingsIdConstant
""");
    if (settingsResult.isEmpty) {
      return const GlobalSettings(
        isFirstTime: true,
        lastUsedVersion: version,
      );
    } else {
      final settingsJson = Map<String, dynamic>.from(
        jsonDecode(
          settingsResult.first[sqldbSettingsJson] as String,
        ),
      );
      return GlobalSettings.fromJson(settingsJson);
    }
  }

  @override
  Future<void> saveSettings(GlobalSettings newSettings) async {
    await _ensureTable();
    await db.execute("""
DELETE FROM $sqldbSettingsTableName
""");
    await db.execute(
      """
INSERT INTO $sqldbSettingsTableName
  ($sqldbSettingsId, $sqldbSettingsJson)
VALUES
  ($sqldbSettingsIdConstant, ?)
""",
      [
        jsonEncode(
          newSettings.toJson(),
        ),
      ],
    );
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

class GlobalSettingsLoaded implements GlobalSettingsState {
  final GlobalSettings settings;
  const GlobalSettingsLoaded({
    required this.settings,
  });
}

class GlobalSettingsCubit extends Cubit<GlobalSettingsState> {
  final SettingsSource settingsSource;

  GlobalSettingsCubit({
    required this.settingsSource,
  }) : super(const GlobalSettingsInitial()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    emit(const GlobalSettingsLoading());
    emit(
      GlobalSettingsLoaded(
        settings: await settingsSource.getSavedSettings(),
      ),
    );
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
  }

  Future<void> saveSettings(GlobalSettings newSettings) async {
    await settingsSource.saveSettings(newSettings);
  }
}
