import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

class EmoticImage extends Equatable {
  final int id;
  final Uri? parentDirectoryUri;
  final Uri imageUri;
  final List<String> tags;
  final String note;
  final bool isExcluded;
  const EmoticImage({
    required this.id,
    required this.imageUri,
    required this.parentDirectoryUri,
    required this.tags,
    required this.note,
    required this.isExcluded,
  });
  @override
  List<Object?> get props => [
        id,
        imageUri,
        parentDirectoryUri,
        tags,
        note,
        isExcluded,
      ];
}

class NewOrModifyEmoticImage extends Equatable {
  final Uri imageUri;

  /// If this is null, it means the image was selected by itself, not the
  /// directory, so it is copied to app data directory
  final Uri? parentDirectoryUri;

  final List<String> tags;
  final String note;
  final EmoticImage? oldImage;
  final bool isExcluded;
  const NewOrModifyEmoticImage({
    required this.imageUri,
    required this.parentDirectoryUri,
    required this.tags,
    required this.note,
    this.oldImage,
    this.isExcluded = false,
  });
  @override
  List<Object?> get props => [
        imageUri,
        parentDirectoryUri,
        tags,
        note,
        oldImage,
      ];

  /// New image with only essential params and the others blank/null
  NewOrModifyEmoticImage.newImage({
    required this.imageUri,
    required this.parentDirectoryUri,
  })  : tags = [],
        note = "",
        isExcluded = false,
        oldImage = null;

  /// Copy from an oldImage, and keep reference to it
  NewOrModifyEmoticImage.modify({
    required EmoticImage this.oldImage,
    List<String>? tags,
    String? note,
    bool? isExcluded,
  })  : imageUri = oldImage.imageUri,
        parentDirectoryUri = oldImage.parentDirectoryUri,
        tags = tags ?? oldImage.tags,
        note = note ?? oldImage.note,
        isExcluded = isExcluded ?? oldImage.isExcluded;

  /// Copy from an oldImage, but without keeping reference to oldImage
  NewOrModifyEmoticImage.copyImage({
    required EmoticImage oldImage,
    Uri? imageUri,
    Option<Uri>? parentDirectoryUri,
    List<String>? tags,
    String? note,
    bool? isExcluded,
  })  : oldImage = null,
        imageUri = imageUri ?? oldImage.imageUri,
        parentDirectoryUri = parentDirectoryUri == null
            ? oldImage.parentDirectoryUri
            : switch (parentDirectoryUri) {
                Some(:final value) => value,
                None() => null,
              },
        tags = tags ?? oldImage.tags,
        note = note ?? oldImage.note,
        isExcluded = isExcluded ?? oldImage.isExcluded;
}
