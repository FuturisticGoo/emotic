// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Settings _$SettingsFromJson(Map<String, dynamic> json) => Settings(
      isFirstTime: json['isFirstTime'] as bool,
      lastUsedVersion: json['lastUsedVersion'] as String,
    );

Map<String, dynamic> _$SettingsToJson(Settings instance) => <String, dynamic>{
      'isFirstTime': instance.isFirstTime,
      'lastUsedVersion': instance.lastUsedVersion,
    };
