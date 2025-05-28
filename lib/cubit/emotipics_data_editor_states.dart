part of 'emotipics_data_editor_cubit.dart';

sealed class EmotipicsDataEditorState {
  const EmotipicsDataEditorState();
}

class EmotipicsDataEditorInitial implements EmotipicsDataEditorState {}

class EmotipicsDataEditorLoading implements EmotipicsDataEditorState {}

class EmotipicsDataEditorNotEditing implements EmotipicsDataEditorState {}

sealed class EmotipicsDataEditorEditing
    with EquatableMixin
    implements EmotipicsDataEditorState {
  final List<EmoticImage> images;
  final List<String> allTags;
  const EmotipicsDataEditorEditing({
    required this.images,
    required this.allTags,
  });
  @override
  List<Object?> get props => [
        images,
        allTags,
      ];
}

class EmotipicsDataEditorModifyTagLink extends EmotipicsDataEditorEditing {
  final EmoticImage? selectedImage;
  const EmotipicsDataEditorModifyTagLink({
    required super.images,
    required super.allTags,
    required this.selectedImage,
  });
  @override
  List<Object?> get props => [
        images,
        allTags,
        selectedImage,
      ];
}

class EmotipicsDataEditorModifyOrder extends EmotipicsDataEditorEditing {
  const EmotipicsDataEditorModifyOrder({
    required super.images,
    required super.allTags,
  });
}

class EmotipicsDataEditorDelete extends EmotipicsDataEditorEditing {
  final List<EmoticImage> selectedImages;
  final List<String> selectedTags;
  const EmotipicsDataEditorDelete({
    required super.images,
    required super.allTags,
    required this.selectedImages,
    required this.selectedTags,
  });
  @override
  List<Object?> get props => [
        images,
        allTags,
        selectedImages,
        selectedTags,
      ];
}
