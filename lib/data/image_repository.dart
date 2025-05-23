import 'dart:typed_data';

import 'package:emotic/core/emotic_image.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/status_entities.dart';
import 'package:emotic/data/image_source.dart';
import 'package:fpdart/fpdart.dart';

class ImageRepository {
  final ImageSource imageSource;
  const ImageRepository({
    required this.imageSource,
  });

  Future<Either<Failure, List<EmoticImage>>> getImages() async {
    try {
      final result = await imageSource.getImages();
      return Either.right(result);
    } catch (error, stackTrace) {
      getLogger().severe(
        "Error while loading images",
        error,
        stackTrace,
      );
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, Uint8List>> getImageBytes({
    required Uri imageUri,
  }) async {
    try {
      final result = await imageSource.getImageBytes(imageUri: imageUri);
      return Either.right(result);
    } on FileDoesNotExistException {
      return Either.left(CannotReadFileFailure());
    } on CannotReadFromContentUriException {
      return Either.left(CannotReadFileFailure());
    } on UnknownUriSchemeException {
      return Either.left(CannotReadFileFailure());
    } catch (error, stackTrace) {
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, Success>> pickImagesAndSave() async {
    try {
      await imageSource.pickImagesAndSave();
      return Either.right(GenericSuccess());
    } on NoImagePickedException {
      getLogger().info("User cancelled the image picking action");
      return Either.left(FilePickingCancelledFailure());
    } catch (error, stackTrace) {
      getLogger()
          .severe("Unknown error while picking image", error, stackTrace);
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, Success>> pickDirectoryAndSaveImages() async {
    try {
      await imageSource.pickDirectoryAndSaveImages();
      return Either.right(GenericSuccess());
    } on NoDirectoryPickedException {
      return Either.left(FilePickingCancelledFailure());
    } on NoImageInDirectoryException {
      return Either.left(NoImagesFoundFailure());
    } catch (error, stackTrace) {
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, Success>> saveImage({
    required NewOrModifyEmoticImage image,
  }) async {
    try {
      await imageSource.saveImage(image: image);
      return Either.right(GenericSuccess());
    } catch (error, stackTrace) {
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, Success>> deleteImage({
    required EmoticImage image,
  }) async {
    try {
      await imageSource.deleteImage(imageId: image.id);
      return Either.right(GenericSuccess());
    } catch (error, stackTrace) {
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, List<String>>> getTags() async {
    try {
      final tags = await imageSource.getTags();
      return Either.right(tags);
    } catch (error, stackTrace) {
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, Success>> saveTag({required String tag}) async {
    try {
      await imageSource.saveTag(tag: tag);
      return Either.right(GenericSuccess());
    } catch (error, stackTrace) {
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, Success>> deleteTag({required String tag}) async {
    try {
      await imageSource.deleteTag(tag: tag);
      return Either.right(GenericSuccess());
    } catch (error, stackTrace) {
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, Success>> clearAllData() async {
    try {
      await imageSource.clearAllData();
      return Either.right(GenericSuccess());
    } catch (error, stackTrace) {
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, Success>> modifyImageOrder({
    required EmoticImage image,
    required int newOrder,
  }) async {
    try {
      await imageSource.modifyImageOrder(
        image: image,
        newOrder: newOrder,
      );
      return Either.right(GenericSuccess());
    } catch (error, stackTrace) {
      return Either.left(GenericFailure(error, stackTrace));
    }
  }

  Future<Either<Failure, Success>> modifyTagOrder({
    required String tag,
    required int newOrder,
  }) async {
    try {
      await imageSource.modifyTagOrder(
        tag: tag,
        newOrder: newOrder,
      );
      return Either.right(GenericSuccess());
    } catch (error, stackTrace) {
      return Either.left(GenericFailure(error, stackTrace));
    }
  }
}
