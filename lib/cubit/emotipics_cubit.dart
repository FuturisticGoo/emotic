import 'package:emotic/core/emotic_image.dart';
import 'package:emotic/core/image_data.dart';
import 'package:emotic/core/status_entities.dart';
import 'package:emotic/data/image_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:emotic/core/helper_functions.dart' as hf;
import 'package:fuzzy/fuzzy.dart';
part 'emotipics_state.dart';

class EmotipicsListingCubit extends Cubit<EmotipicsListingState> {
  final ImageRepository imageRepository;
  EmotipicsListingCubit({
    required this.imageRepository,
  }) : super(EmotipicsListingInitial()) {
    loadSavedImages();
  }

  Future<void> loadSavedImages({bool showExcluded = false}) async {
    emit(EmotipicsListingLoading());
    final imagesResult = await imageRepository.getImages();
    final tagsResult = await imageRepository.getTags();
    switch ((imagesResult, tagsResult)) {
      case (Right(value: final images), Right(value: final allTag)):
        emit(
          EmotipicsListingLoaded(
            images: images,
            imagesToShow: images.where(
              (element) {
                return !element.isExcluded || showExcluded;
              },
            ).toList(),
            visibleImageData: {},
            allTags: allTag,
          ),
        );
      default:
        emit(EmotipicsListingError());
    }
  }

  Future<void> unloadImageBytes({required Uri imageToUnload}) async {
    if (state
        case EmotipicsListingLoaded(
          :final images,
          :final imagesToShow,
          :var visibleImageData,
          :final allTags
        )) {
      visibleImageData.remove(imageToUnload);
      emit(
        EmotipicsListingLoaded(
          images: images,
          imagesToShow: imagesToShow,
          visibleImageData: visibleImageData,
          allTags: allTags,
        ),
      );
    }
  }

  Future<void> loadImageBytes({
    required Uri imageToLoad,
    ImageReprConfig? imageReprConfig,
  }) async {
    if (state case EmotipicsListingLoaded()) {
      final Either<Failure, ImageRepr> bytesResult =
          await imageRepository.getImageData(
        imageUri: imageToLoad,
        imageReprConfig:
            imageReprConfig ?? FlutterImageWidgetReprConfig.thumbnail(),
      );
      if (state
          case EmotipicsListingLoaded(
            :final images,
            :final allTags,
            :final visibleImageData,
            :final imagesToShow,
          )) {
        // Doing this case again because there could be concurrent calls to this
        // function, so visibleImageData might have updated during the
        // above time
        emit(
          EmotipicsListingLoaded(
            images: images,
            imagesToShow: imagesToShow,
            allTags: allTags,
            visibleImageData: {
              ...visibleImageData,
              imageToLoad: bytesResult,
            },
          ),
        );
      }
    }
  }

  Future<void> copyImageToClipboard({required EmoticImage emoticImage}) async {
    if (state case EmotipicsListingLoaded()) {
      final bytesResult = await imageRepository.getImageData(
        imageUri: emoticImage.imageUri,
        imageReprConfig: Uint8ListReprConfig(),
      );
      switch (bytesResult) {
        case Right(value: Uint8ListImageRepr(:final imageBytes)):
          final copyResult = await hf.copyImageToClipboard(
            emoticImage: emoticImage,
            imageBytes: imageBytes,
          );
          switch (copyResult) {
            case Right():
              if (state
                  case EmotipicsListingLoaded(
                    :final images,
                    :final imagesToShow,
                    :final visibleImageData,
                    :final allTags,
                  )) {
                emit(
                  EmotipicsListingLoaded(
                    images: images,
                    imagesToShow: imagesToShow,
                    visibleImageData: visibleImageData,
                    allTags: allTags,
                    snackBarMessage: "Image copied!",
                  ),
                );
              }
            case Left():
              continue errorSnackBar;
          }
        case Right():
          // Should not happen because we specifically requested for image bytes
          continue errorSnackBar;
        errorSnackBar:
        case Left():
          if (state
              case EmotipicsListingLoaded(
                :final images,
                :final imagesToShow,
                :final visibleImageData,
                :final allTags
              )) {
            emit(
              EmotipicsListingLoaded(
                images: images,
                imagesToShow: imagesToShow,
                visibleImageData: visibleImageData,
                allTags: allTags,
                snackBarMessage: "Unable to copy image",
              ),
            );
          }
      }
    }
  }

  Future<void> shareImage({required EmoticImage image}) async {
    if (state case EmotipicsListingLoaded()) {
      final bytesResult = await imageRepository.getImageData(
        imageUri: image.imageUri,
        imageReprConfig: Uint8ListReprConfig(),
      );
      switch (bytesResult) {
        case Right(value: Uint8ListImageRepr(:final imageBytes)):
          final shareResult = await hf.shareImage(
            emoticImage: image,
            imageBytes: imageBytes,
          );
          if (shareResult case Left()) {
            continue errorSnackBar;
          }
        case Right():
          // Should not happen because we specifically requested for image bytes
          continue errorSnackBar;
        errorSnackBar:
        case Left():
          if (state
              case EmotipicsListingLoaded(
                :final images,
                :final imagesToShow,
                :final visibleImageData,
                :final allTags
              )) {
            emit(
              EmotipicsListingLoaded(
                images: images,
                imagesToShow: imagesToShow,
                visibleImageData: visibleImageData,
                allTags: allTags,
                snackBarMessage: "Unable to share image",
              ),
            );
          }
      }
    }
  }

  Future<void> searchWithText({required String searchText}) async {
    final searchTermTrimmed = searchText.trim();
    if (state
        case EmotipicsListingLoaded(
          :final images,
          :final visibleImageData,
          :final allTags
        )) {
      if (searchTermTrimmed.isEmpty) {
        emit(
          EmotipicsListingLoaded(
            images: images,
            imagesToShow: images,
            visibleImageData: visibleImageData,
            allTags: allTags,
          ),
        );
        return;
      }
      final tagFuzzy = Fuzzy<String>(
        allTags,
        options: FuzzyOptions(
          tokenSeparator: ",",
          tokenize: true,
        ),
      );

      final notesFuzzy = Fuzzy<String>(
        images
            .map(
              (e) => e.note,
            )
            .toList(),
        options: FuzzyOptions(
          tokenSeparator: ",",
          tokenize: true,
        ),
      );
      final tagSearchResult = tagFuzzy
          .search(
            searchTermTrimmed,
            1,
          )
          .where((e) {
            return e.score < 0.5;
          })
          .map(
            (e) => e.item,
          )
          .toSet();
      final notesSearchResult = notesFuzzy
          .search(
        searchTermTrimmed,
        1,
      )
          .where((e) {
        return e.score < 0.4;
      }).map(
        (e) => e.item,
      );
      final result = images.where(
        (element) {
          return element.tags
                  .toSet()
                  .intersection(tagSearchResult)
                  .isNotEmpty ||
              notesSearchResult.contains(element.note);
        },
      ).toList();
      emit(
        EmotipicsListingLoaded(
          images: images,
          imagesToShow: result,
          visibleImageData: visibleImageData,
          allTags: allTags,
        ),
      );
    }
  }
}
