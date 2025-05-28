import 'package:emotic/core/emotic_image.dart';
import 'package:emotic/core/functional_list_methods.dart';
import 'package:emotic/data/image_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
part 'emotipics_data_editor_states.dart';

class EmotipicsDataEditorCubit extends Cubit<EmotipicsDataEditorState> {
  final ImageRepository imageRepository;
  EmotipicsDataEditorCubit({
    required this.imageRepository,
  }) : super(EmotipicsDataEditorInitial()) {
    emit(EmotipicsDataEditorNotEditing());
  }

  Future<void> startDeleting({
    required List<EmoticImage> images,
    required List<String> allTags,
  }) async {
    emit(
      EmotipicsDataEditorDelete(
        images: images,
        allTags: allTags,
        selectedImages: [],
        selectedTags: [],
      ),
    );
  }

  Future<void> startModifyingOrder({
    required List<EmoticImage> images,
    required List<String> allTags,
  }) async {
    emit(
      EmotipicsDataEditorModifyOrder(
        images: images,
        allTags: allTags,
      ),
    );
  }

  Future<void> reorderEmotipic({
    required int oldIndex,
    required int newIndex,
  }) async {
    if (state
        case EmotipicsDataEditorModifyOrder(
          :final images,
          :final allTags,
        )) {
      var newEmotipicsOrder = images.sublist(0);
      final image = newEmotipicsOrder.removeAt(oldIndex);
      newEmotipicsOrder.insert(newIndex, image);
      emit(
        EmotipicsDataEditorModifyOrder(
          images: newEmotipicsOrder,
          allTags: allTags,
        ),
      );

      await imageRepository.modifyImageOrder(
        image: image,
        newOrder: newIndex,
      );
      // TODO: cant emit notEditing cuz we don't want to get out of reorder, but
      // have to update the listing somehow
    }
  }

  Future<void> reorderTag({
    required int oldIndex,
    required int newIndex,
  }) async {
    if (state
        case EmotipicsDataEditorModifyOrder(
          :final images,
          :final allTags,
        )) {
      var newTagsOrder = allTags.sublist(0);
      final tag = newTagsOrder.removeAt(oldIndex);
      newTagsOrder.insert(newIndex, tag);
      emit(
        EmotipicsDataEditorModifyOrder(
          images: images,
          allTags: newTagsOrder,
        ),
      );

      await imageRepository.modifyTagOrder(
        tag: tag,
        newOrder: newIndex,
      );
      // TODO: cant emit notEditing cuz we don't want to get out of reorder, but
      // have to update the listing somehow
    }
  }

  Future<void> startModifyingTagLink({
    required List<EmoticImage> images,
    required List<String> allTags,
  }) async {
    emit(
      EmotipicsDataEditorModifyTagLink(
        images: images,
        allTags: allTags,
        selectedImage: null,
      ),
    );
  }

  Future<void> selectEmotipic({required EmoticImage image}) async {
    switch (state) {
      case EmotipicsDataEditorModifyTagLink(
          :final images,
          :final allTags,
          :final selectedImage,
        ):
        emit(
          EmotipicsDataEditorModifyTagLink(
            images: images,
            allTags: allTags,
            selectedImage: (image.id == selectedImage?.id) ? null : image,
          ),
        );
      case EmotipicsDataEditorDelete(
          :final images,
          :final allTags,
          :final selectedImages,
          :final selectedTags
        ):
        emit(
          EmotipicsDataEditorDelete(
            images: images,
            allTags: allTags,
            selectedImages: (selectedImages.contains(image))
                ? selectedImages.removeIfExists(image)
                : selectedImages.addIfNotExists(image),
            selectedTags: selectedTags,
          ),
        );
      default:
        break;
    }
  }

  Future<void> selectTag({required String tag}) async {
    //TODO: update listing when saving somehow
    switch (state) {
      case EmotipicsDataEditorModifyTagLink(
            :final images,
            :final allTags,
            :final selectedImage,
          )
          when selectedImage != null:
        await modifyImage(
          newOrModifyEmoticImage: NewOrModifyEmoticImage.modify(
            oldImage: selectedImage,
            tags: (selectedImage.tags.contains(tag))
                ? selectedImage.tags.removeIfExists(tag)
                : selectedImage.tags.addIfNotExists(tag),
            note: selectedImage.note,
            isExcluded: selectedImage.isExcluded,
          ),
        );
      case EmotipicsDataEditorDelete(
          :final images,
          :final allTags,
          :final selectedImages,
          :final selectedTags
        ):
        emit(
          EmotipicsDataEditorDelete(
            images: images,
            allTags: allTags,
            selectedImages: selectedImages,
            selectedTags: (selectedTags.contains(tag))
                ? selectedTags.removeIfExists(tag)
                : selectedTags.addIfNotExists(tag),
          ),
        );
      default:
        break;
    }
  }

  Future<void> addTags({required List<String> tags}) async {
    for (final tag in tags) {
      final result = await imageRepository.saveTag(tag: tag);
    }
  }

  Future<void> deleteImagesAndTags({
    List<EmoticImage>? emoticImages,
    List<String>? tags,
  }) async {
    switch (state) {
      case EmotipicsDataEditorDelete(
          :final selectedImages,
          :final selectedTags
        ):
        for (final image in selectedImages) {
          final result = await imageRepository.deleteImage(image: image);
        }
        for (final tag in selectedTags) {
          final result = await imageRepository.deleteTag(tag: tag);
        }
      default:
        break;
    }
  }

  Future<void> modifyImage({
    required NewOrModifyEmoticImage newOrModifyEmoticImage,
  }) async {
    final result = await imageRepository.saveImage(
      image: newOrModifyEmoticImage,
    );
  }
}
