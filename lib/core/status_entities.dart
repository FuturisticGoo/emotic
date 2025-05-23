// Success
sealed class Success {}

class GenericSuccess implements Success {}

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

class FileDoesNotExistException implements Exception {}

class CannotReadFromContentUriException implements Exception {}

class UnknownUriSchemeException implements Exception {}
