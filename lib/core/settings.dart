import 'dart:convert';

import 'package:emotic/core/constants.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sqlite3/sqlite3.dart';
part 'settings.g.dart';

@JsonSerializable()
class Settings extends Equatable {
  final bool isFirstTime;
  final String lastUsedVersion;
  bool get isUpdated {
    return lastUsedVersion != version;
  }

  const Settings({
    required this.isFirstTime,
    required this.lastUsedVersion,
  });
  Map<String, dynamic> toJson() => _$SettingsToJson(this);
  factory Settings.fromJson(Map<String, dynamic> json) =>
      _$SettingsFromJson(json);
  @override
  List<Object?> get props => [
        isFirstTime,
        lastUsedVersion,
      ];
}

abstract class SettingsSource {
  Future<Settings> getSavedSettings();
  Future<void> saveSettings(Settings newSettings);
}

class SettingsSourceDb implements SettingsSource {
  final Database db;
  SettingsSourceDb({required this.db});
  Future<void> _ensureTable() async {
    db.execute("""
CREATE TABLE IF NOT EXISTS $sqldbSettingsTableName
  (
    $sqldbSettingsId INTEGER,
    $sqldbSettingsJson VARCHAR
  )
""");
  }

  @override
  Future<Settings> getSavedSettings() async {
    await _ensureTable();
    final settingsResult = db.select("""
SELECT $sqldbSettingsJson FROM $sqldbSettingsTableName
WHERE $sqldbSettingsId==$sqldbSettingsIdConstant
""");
    if (settingsResult.isEmpty) {
      return const Settings(
        isFirstTime: true,
        lastUsedVersion: version,
      );
    } else {
      final settingsJson = Map<String, dynamic>.from(
        jsonDecode(
          settingsResult.first[sqldbSettingsJson],
        ),
      );
      return Settings.fromJson(settingsJson);
    }
  }

  @override
  Future<void> saveSettings(Settings newSettings) async {
    await _ensureTable();
    db.execute("""
DELETE FROM $sqldbSettingsTableName
""");
    db.execute(
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

sealed class SettingsState {
  const SettingsState();
}

class SettingsInitial implements SettingsState {
  const SettingsInitial();
}

class SettingsLoading implements SettingsState {
  const SettingsLoading();
}

class SettingsLoaded implements SettingsState {
  final Settings settings;
  const SettingsLoaded({
    required this.settings,
  });
}

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsSource settingsSource;

  SettingsCubit({
    required this.settingsSource,
  }) : super(const SettingsInitial()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    emit(const SettingsLoading());
    emit(
      SettingsLoaded(
        settings: await settingsSource.getSavedSettings(),
      ),
    );
  }

  Future<void> refreshSettings() async {
    await _loadSettings();
  }

  Future<void> saveSettings(Settings newSettings) async {
    await settingsSource.saveSettings(newSettings);
  }
}
