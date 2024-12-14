import 'package:emotic/core/emoticon.dart';
import 'package:equatable/equatable.dart';

sealed class TagEditorState extends Equatable {}

class TagEditorInitial extends TagEditorState {
  @override
  List<Object?> get props => [];
}

class TagEditorLoading extends TagEditorState {
  @override
  List<Object?> get props => [];
}

class TagEditorLoaded extends TagEditorState {
  final List<Emoticon> allEmoticons;
  final List<String> allTags;
  final Emoticon? selectedEmoticon;
  TagEditorLoaded({
    required this.allEmoticons,
    required this.allTags,
    required this.selectedEmoticon,
  });
  @override
  List<Object?> get props => [
        allEmoticons,
        allTags,
        selectedEmoticon,
      ];
}
