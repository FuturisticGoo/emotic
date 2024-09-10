// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'emoticon.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Emoticon _$EmoticonFromJson(Map<String, dynamic> json) => Emoticon(
      id: (json['id'] as num?)?.toInt(),
      text: json['text'] as String,
      emoticonTags: (json['emoticonTags'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$EmoticonToJson(Emoticon instance) => <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'emoticonTags': instance.emoticonTags,
    };
