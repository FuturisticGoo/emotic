import 'package:emotic/core/emotic_image.dart';
import 'package:emotic/core/functional_list_methods.dart';
import 'package:emotic/core/image_data.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/status_entities.dart';
import 'package:emotic/data/image_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
part 'emotipics_data_editor_states.dart';

class EmotipicsDataEditorCubit extends Cubit<EmotipicsDataEditorState> {
  final ImageRepository imageRepository;
  EmotipicsDataEditorCubit({
    required this.imageRepository,
  }) : super(EmotipicsDataEditorInitial()) {
    emit(EmotipicsDataEditorNotEditing());
  }

  // :( this is duplicating the same code in EmoitipicsCubit because I cant
  // seem to find a neat way of loading the data after editing
  Future<void> loadSavedImages({String? snackBarMessage}) async {
    final imagesResult = await imageRepository.getImages();
    final tagsResult = await imageRepository.getTags();
    switch ((imagesResult, tagsResult)) {
      case (Right(value: final images), Right(value: final allTags)):
        await _updateWithData(
          images: images,
          allTags: allTags,
          snackBarMessage: snackBarMessage,
          visibleImageData: {},
        );
      default:
        //TODO: handle error
        return;
    }
  }

  Future<void> refreshImages() async {
    final result = await imageRepository.refreshImages();
    switch (result) {
      case Left():
        //TODO: handle
        break;
      case Right(:final value):
        await loadSavedImages(
            snackBarMessage: "Added ${value.newImages} and removed"
                " ${value.deletedImages} images.");
    }
  }

  Future<void> unloadImageBytes({required Uri imageToUnload}) async {
    if (state
        case EmotipicsDataEditorEditing(
          :final images,
          :final allTags,
          :final visibleImageData,
        )) {
      visibleImageData.remove(imageToUnload);
      await _updateWithData(
          images: images, allTags: allTags, visibleImageData: visibleImageData);
    }
  }

  Future<void> loadImageBytes({required Uri imageToLoad}) async {
    if (state case EmotipicsDataEditorEditing()) {
      final Either<Failure, ImageRepr> bytesResult =
          await imageRepository.getImageData(
        imageUri: imageToLoad,
        imageReprConfig: FlutterImageWidgetReprConfig.thumbnail(),
      );
      switch (bytesResult) {
        case Left():
          break;
        case Right(value: final bytes):
          if (state
              case EmotipicsDataEditorEditing(
                :final images,
                :final allTags,
                :final visibleImageData,
              )) {
            // Doing this again because there could be concurrent calls to this
            // function, so visibleImageData might have updated during the
            // above time
            await _updateWithData(
              images: images,
              allTags: allTags,
              visibleImageData: {
                ...visibleImageData,
                imageToLoad: bytes,
              },
            );
          }
      }
    }
  }

  Future<void> _updateWithData({
    required List<EmoticImage> images,
    required List<String> allTags,
    required Map<Uri, ImageRepr> visibleImageData,
    String? snackBarMessage,
  }) async {
    switch (state) {
      case EmotipicsDataEditorNotEditing() when snackBarMessage != null:
        emit(EmotipicsDataEditorNotEditing(snackBarMessage: snackBarMessage));
      case EmotipicsDataEditorInitial():
      case EmotipicsDataEditorLoading():
      case EmotipicsDataEditorNotEditing():
        break;
      case EmotipicsDataEditorModifyOrder():
        emit(
          EmotipicsDataEditorModifyOrder(
            images: images,
            allTags: allTags,
            visibleImageData: visibleImageData,
            snackBarMessage: snackBarMessage,
          ),
        );
      case EmotipicsDataEditorModifyTagLink(:final selectedImage):
        emit(
          EmotipicsDataEditorModifyTagLink(
            images: images,
            allTags: allTags,
            visibleImageData: visibleImageData,
            snackBarMessage: snackBarMessage,
            selectedImage: images.singleWhereOrNull(
              (element) => element.id == selectedImage?.id,
              // Because selectedImage would have updated, so using the one
              // from source
            ),
          ),
        );
      case EmotipicsDataEditorDelete(
          :final selectedImages,
          :final selectedTags
        ):
        emit(
          EmotipicsDataEditorDelete(
            images: images,
            allTags: allTags,
            visibleImageData: visibleImageData,
            snackBarMessage: snackBarMessage,
            // Doing this set stuff because we could reach here in two
            // situations, either the selectedImages were deleted and now its
            // updating (so selectedImages shouldnt be shown anymore, so []),
            // or while on delete page new images were added (selectedImages
            // should be the same)
            selectedImages:
                images.toSet().intersection(selectedImages.toSet()).toList(),
            selectedTags:
                allTags.toSet().intersection(selectedTags.toSet()).toList(),
          ),
        );
    }
  }

  Future<void> startDeleting({
    required List<EmoticImage> images,
    required List<String> allTags,
    required Map<Uri, ImageRepr> visibleImageData,
  }) async {
    switch (state) {
      case EmotipicsDataEditorEditing(
          :final images,
          :final allTags,
          :final visibleImageData
        ):
        emit(
          EmotipicsDataEditorDelete(
            images: images,
            allTags: allTags,
            selectedImages: [],
            selectedTags: [],
            visibleImageData: visibleImageData,
          ),
        );
      default:
        emit(
          EmotipicsDataEditorDelete(
            images: images,
            allTags: allTags,
            selectedImages: [],
            selectedTags: [],
            visibleImageData: visibleImageData,
          ),
        );
    }
  }

  Future<void> startModifyingOrder({
    required List<EmoticImage> images,
    required List<String> allTags,
    required Map<Uri, ImageRepr> visibleImageData,
  }) async {
    switch (state) {
      case EmotipicsDataEditorEditing(
          :final images,
          :final allTags,
          :final visibleImageData
        ):
        emit(
          EmotipicsDataEditorModifyOrder(
            images: images,
            allTags: allTags,
            visibleImageData: visibleImageData,
          ),
        );
      default:
        emit(
          EmotipicsDataEditorModifyOrder(
            images: images,
            allTags: allTags,
            visibleImageData: visibleImageData,
          ),
        );
    }
  }

  Future<void> startModifyingTagLink({
    required List<EmoticImage> images,
    required List<String> allTags,
    required Map<Uri, ImageRepr> visibleImageData,
  }) async {
    switch (state) {
      case EmotipicsDataEditorEditing(
          :final images,
          :final allTags,
          :final visibleImageData
        ):
        emit(
          EmotipicsDataEditorModifyTagLink(
            images: images,
            allTags: allTags,
            selectedImage: null,
            visibleImageData: visibleImageData,
          ),
        );
      default:
        emit(
          EmotipicsDataEditorModifyTagLink(
            images: images,
            allTags: allTags,
            selectedImage: null,
            visibleImageData: visibleImageData,
          ),
        );
    }
  }

  Future<void> reorderEmotipic({
    required int oldIndex,
    required int newIndex,
  }) async {
    if (state
        case EmotipicsDataEditorModifyOrder(
          :final images,
          :final allTags,
          :final visibleImageData,
        )) {
      var newEmotipicsOrder = images.sublist(0);
      final image = newEmotipicsOrder.removeAt(oldIndex);
      newEmotipicsOrder.insert(newIndex, image);
      emit(
        EmotipicsDataEditorModifyOrder(
          images: newEmotipicsOrder,
          allTags: allTags,
          visibleImageData: visibleImageData,
        ),
      );

      await imageRepository.modifyImageOrder(
        image: image,
        newOrder: newIndex,
      );
      await loadSavedImages();
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
          :final visibleImageData,
        )) {
      var newTagsOrder = allTags.sublist(0);
      final tag = newTagsOrder.removeAt(oldIndex);
      newTagsOrder.insert(newIndex, tag);
      emit(
        EmotipicsDataEditorModifyOrder(
          images: images,
          allTags: newTagsOrder,
          visibleImageData: visibleImageData,
        ),
      );
      await imageRepository.modifyTagOrder(
        tag: tag,
        newOrder: newIndex,
      );
      await loadSavedImages();
    }
  }

  Future<void> selectEmotipic({required EmoticImage image}) async {
    switch (state) {
      case EmotipicsDataEditorModifyTagLink(
          :final images,
          :final allTags,
          :final selectedImage,
          :final visibleImageData
        ):
        emit(
          EmotipicsDataEditorModifyTagLink(
            images: images,
            allTags: allTags,
            selectedImage: (image.id == selectedImage?.id) ? null : image,
            visibleImageData: visibleImageData,
          ),
        );
      case EmotipicsDataEditorDelete(
          :final images,
          :final allTags,
          :final selectedImages,
          :final selectedTags,
          :final visibleImageData,
        ):
        emit(
          EmotipicsDataEditorDelete(
            images: images,
            allTags: allTags,
            selectedImages: (selectedImages.contains(image))
                ? selectedImages.removeIfExists(image)
                : selectedImages.addIfNotExists(image),
            selectedTags: selectedTags,
            visibleImageData: visibleImageData,
          ),
        );
      default:
        break;
    }
  }

  Future<void> selectTag({required String tag}) async {
    switch (state) {
      case EmotipicsDataEditorModifyTagLink(
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
        await loadSavedImages();
      case EmotipicsDataEditorDelete(
          :final images,
          :final allTags,
          :final selectedImages,
          :final selectedTags,
          :final visibleImageData
        ):
        emit(
          EmotipicsDataEditorDelete(
            images: images,
            allTags: allTags,
            selectedImages: selectedImages,
            selectedTags: (selectedTags.contains(tag))
                ? selectedTags.removeIfExists(tag)
                : selectedTags.addIfNotExists(tag),
            visibleImageData: visibleImageData,
          ),
        );
      default:
        break;
    }
  }

  Future<void> pickImages() async {
    final pickResult = await imageRepository.pickImagesAndSave();
    switch (pickResult) {
      case Left(value: final error):
        getLogger().severe(
          "pick image failed",
          error,
        );
        break; // TODO: maybe a toast message?
      case Right():
        await loadSavedImages();
    }
  }

  Future<void> pickDirectory() async {
    final pickResult = await imageRepository.pickDirectoryAndSaveImages();
    switch (pickResult) {
      case Left(value: final error):
        getLogger().severe(
          "pick directory failed",
          error,
        );
        break; // TODO: maybe a toast message?
      case Right():
        await loadSavedImages();
    }
  }

  Future<void> addTags({required List<String> tags}) async {
    for (final tag in tags) {
      final result = await imageRepository.saveTag(tag: tag);
    }
    await loadSavedImages();
  }

  Future<void> deleteImagesAndTags({
    required List<EmoticImage> emoticImages,
    required List<String> tags,
  }) async {
    for (final image in emoticImages) {
      final result = await imageRepository.deleteImage(image: image);
    }
    for (final tag in tags) {
      final result = await imageRepository.deleteTag(tag: tag);
    }
    await loadSavedImages();
  }

  Future<void> modifyImage({
    required NewOrModifyEmoticImage newOrModifyEmoticImage,
  }) async {
    final result = await imageRepository.saveImage(
      image: newOrModifyEmoticImage,
    );
    await loadSavedImages();
  }

  Future<void> finishEditing() async {
    emit(EmotipicsDataEditorNotEditing());
  }
}
