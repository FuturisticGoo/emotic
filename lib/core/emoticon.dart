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
  const NewOrModifyEmoticon.newEmoticon()
      : this(
          text: "",
          emoticonTags: const [],
          oldEmoticon: null,
        );
  NewOrModifyEmoticon.fromExistingEmoticon(Emoticon emoticon)
      : this(
          text: emoticon.text,
          emoticonTags: emoticon.emoticonTags,
          oldEmoticon: emoticon,
        );
  @override
  List<Object?> get props => [
        text,
        emoticonTags,
        oldEmoticon,
      ];
}
