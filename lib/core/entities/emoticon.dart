import 'package:equatable/equatable.dart';

class Emoticon extends Equatable {
  final int id;
  final String text;
  final List<String> emoticonTags;
  const Emoticon({
    required this.id,
    required this.text,
    required this.emoticonTags,
  });
  @override
  List<Object?> get props => [id, text, emoticonTags];
}

class NewOrModifyEmoticon extends Equatable {
  final String text;
  final List<String> emoticonTags;
  final Emoticon? oldEmoticon;
  const NewOrModifyEmoticon({
    required this.text,
    required this.emoticonTags,
    required this.oldEmoticon,
  });

  /// New emoticon with everything blank
  const NewOrModifyEmoticon.newEmoticon()
      : this(
          text: "",
          emoticonTags: const [],
          oldEmoticon: null,
        );

  /// Modify and existing emoticon
  NewOrModifyEmoticon.editExistingEmoticon(Emoticon emoticon)
      : this(
          text: emoticon.text,
          emoticonTags: emoticon.emoticonTags,
          oldEmoticon: emoticon,
        );

  /// Copy from another emoticon, but not for modifying that emoticon
  NewOrModifyEmoticon.copyFromEmoticon(Emoticon emoticon)
      : this(
          text: emoticon.text,
          emoticonTags: emoticon.emoticonTags,
          oldEmoticon: null,
        );
  @override
  List<Object?> get props => [
        text,
        emoticonTags,
        oldEmoticon,
      ];
}
