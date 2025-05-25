import 'package:emotic/core/emotic_image.dart';
import 'package:emotic/core/image_data.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/status_entities.dart';
import 'package:emotic/data/image_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:emotic/core/helper_functions.dart' as hf;
part 'emotipics_state.dart';

class EmotipicsListingCubit extends Cubit<EmotipicsListingState> {
  final ImageRepository imageRepository;
  EmotipicsListingCubit({
    required this.imageRepository,
  }) : super(EmotipicsListingInitial()) {
    loadSavedImages();
  }

  Future<void> loadSavedImages() async {
    emit(EmotipicsListingLoading());
    final imagesResult = await imageRepository.getImages();
    switch (imagesResult) {
      case Left():
        emit(EmotipicsListingError());
      case Right(value: final images):
        emit(
          EmotipicsListingLoaded(
            images: images,
            visibleImageData: {},
          ),
        );
    }
  }

  Future<void> unloadImageBytes({required Uri imageToUnload}) async {
    if (state
        case EmotipicsListingLoaded(:final images, :var visibleImageData)) {
      visibleImageData.remove(imageToUnload);
      emit(
        EmotipicsListingLoaded(
          images: images,
          visibleImageData: visibleImageData,
        ),
      );
    }
  }

  Future<void> loadImageBytes({required Uri imageToLoad}) async {
    if (state case EmotipicsListingLoaded(:final images)) {
      final Either<Failure, ImageRepr> bytesResult =
          await imageRepository.getImageData(
        imageUri: imageToLoad,
        imageReprConfig: FlutterImageWidgetReprConfig.thumbnail(),
      );
      // TODO: handle errors, maybe the map
      switch (bytesResult) {
        case Left():
          break;
        case Right(value: final bytes):
          if (state case EmotipicsListingLoaded(:final visibleImageData)) {
            // Doing this again because there could be concurrent calls to this
            // function, so visibleImageData might have updated during the
            // above time
            emit(
              EmotipicsListingLoaded(
                images: images,
                visibleImageData: {
                  ...visibleImageData,
                  imageToLoad: bytes,
                },
              ),
            );
          }
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
                    :final visibleImageData
                  )) {
                emit(
                  EmotipicsListingLoaded(
                    images: images,
                    visibleImageData: visibleImageData,
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
                :final visibleImageData
              )) {
            emit(
              EmotipicsListingLoaded(
                images: images,
                visibleImageData: visibleImageData,
                snackBarMessage: "Unable to copy image",
              ),
            );
          }
      }
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
}
