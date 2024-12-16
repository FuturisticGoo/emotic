// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GlobalSettings _$GlobalSettingsFromJson(Map<String, dynamic> json) =>
    GlobalSettings(
      isFirstTime: json['isFirstTime'] as bool,
      lastUsedVersion: json['lastUsedVersion'] as String,
    );

Map<String, dynamic> _$GlobalSettingsToJson(GlobalSettings instance) =>
    <String, dynamic>{
      'isFirstTime': instance.isFirstTime,
      'lastUsedVersion': instance.lastUsedVersion,
    };
