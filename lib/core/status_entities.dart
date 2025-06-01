// Success
sealed class Success {
  const Success();
}

class GenericSuccess implements Success {}

class RefreshImageSuccess implements Success {
  final int newImages;
  final int deletedImages;
  const RefreshImageSuccess({
    required this.newImages,
    required this.deletedImages,
  });
}

// Failure
sealed class Failure {
  // aka me ;)
}

class GenericFailure implements Failure {
  final Object error;
  final StackTrace stackTrace;
  const GenericFailure(this.error, this.stackTrace);
}

class FilePickingCancelledFailure implements Failure {}

class NoImagesFoundFailure implements Failure {}

class CannotReadFileFailure implements Failure {}

// Exceptions
class NoImagePickedException implements Exception {}

class NoDirectoryPickedException implements Exception {}

class NoImageInDirectoryException implements Exception {}

class CannotReadFromFileException implements Exception {}

class CannotReadFromContentUriException implements Exception {}

class UnknownUriSchemeException implements Exception {}

class EmoticDatabaseNotFoundException implements Exception {}

class NoImportFilePickedException implements Exception {}

class NoSaveFilePickedException implements Exception {}

class UnrecognizedImportFileException implements Exception {}
