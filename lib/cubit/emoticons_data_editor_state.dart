import 'package:emotic/core/emoticon.dart';
import 'package:equatable/equatable.dart';

sealed class EmoticonsDataEditorState {
  const EmoticonsDataEditorState();
}

class EmoticonsDataEditorInitial extends EmoticonsDataEditorState {}

class EmoticonsDataEditorLoading extends EmoticonsDataEditorState {}

class EmoticonsDataEditorNotEditing extends EmoticonsDataEditorState {}

sealed class EmoticonsDataEditorEditing extends EmoticonsDataEditorState
    with EquatableMixin {
  final List<Emoticon> allEmoticons;
  final List<String> allTags;
  EmoticonsDataEditorEditing({
    required this.allEmoticons,
    required this.allTags,
  });
  @override
  List<Object?> get props => [
        allEmoticons,
        allTags,
      ];
}

class EmoticonsDataEditorModifyLinks extends EmoticonsDataEditorEditing {
  final Emoticon? selectedEmoticon;
  EmoticonsDataEditorModifyLinks({
    required super.allEmoticons,
    required super.allTags,
    required this.selectedEmoticon,
  });
  @override
  List<Object?> get props => [
        super.props,
        selectedEmoticon,
      ];
}

class EmoticonsDataEditorModifyOrder extends EmoticonsDataEditorEditing {
  EmoticonsDataEditorModifyOrder({
    required super.allEmoticons,
    required super.allTags,
  });
}

class EmoticonsDataEditorDeleteData extends EmoticonsDataEditorEditing {
  final List<Emoticon> selectedEmoticons;
  final List<String> selectedTags;
  EmoticonsDataEditorDeleteData({
    required super.allEmoticons,
    required super.allTags,
    required this.selectedEmoticons,
    required this.selectedTags,
  });
  @override
  List<Object?> get props => [
        super.props,
        selectedEmoticons,
        selectedTags,
      ];
}
