import 'package:equatable/equatable.dart';

class EmoticImage extends Equatable {
  final int id;
  final Uri? parentDirectoryUri;
  final Uri imageUri;
  final List<String> tags;
  final String note;
  const EmoticImage({
    required this.id,
    required this.imageUri,
    required this.parentDirectoryUri,
    required this.tags,
    required this.note,
  });
  @override
  List<Object?> get props => [
        id,
        imageUri,
        parentDirectoryUri,
        tags,
        note,
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
}
