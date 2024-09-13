import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'emoticon.g.dart';

@JsonSerializable()
class Emoticon extends Equatable {
  /// id is the unique identifier for an emoticon. If its null, it means
  /// it hasn't been added to the database yet.
  /// This id here is only used for uniqueness within the context of app logic,
  /// it may/may not be same as the one used in the database
  final int? id;
  final String text;
  final List<String> emoticonTags;
  const Emoticon({
    required this.id,
    required this.text,
    required this.emoticonTags,
  });
  @override
  List<Object?> get props => [id, text, emoticonTags];

  Map<String, dynamic> toJson() => _$EmoticonToJson(this);
  factory Emoticon.fromJson(Map<String, dynamic> json) =>
      _$EmoticonFromJson(json);
}
