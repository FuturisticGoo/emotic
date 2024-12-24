import 'package:emotic/core/emoticon.dart';
import 'package:equatable/equatable.dart';

sealed class DataEditorState extends Equatable {}

class DataEditorInitial extends DataEditorState {
  @override
  List<Object?> get props => [];
}

class DataEditorLoading extends DataEditorState {
  @override
  List<Object?> get props => [];
}

class DataEditorLoaded extends DataEditorState {
  final List<Emoticon> allEmoticons;
  final List<String> allTags;
  DataEditorLoaded({
    required this.allEmoticons,
    required this.allTags,
  });
  @override
  List<Object?> get props => [
        allEmoticons,
        allTags,
      ];
}

class DataEditorModifyLinks extends DataEditorLoaded {
  final Emoticon? selectedEmoticon;
  DataEditorModifyLinks({
    required super.allEmoticons,
    required super.allTags,
    required this.selectedEmoticon,
  });
  @override
  List<Object?> get props => [
        allEmoticons,
        allTags,
        selectedEmoticon,
      ];
}

class DataEditorDeleteData extends DataEditorLoaded {
  final List<Emoticon> selectedEmoticons;
  final List<String> selectedTags;
  DataEditorDeleteData({
    required super.allEmoticons,
    required super.allTags,
    required this.selectedEmoticons,
    required this.selectedTags,
  });
  @override
  List<Object?> get props => [
        allEmoticons,
        allTags,
        selectedEmoticons,
        selectedTags,
      ];
}
