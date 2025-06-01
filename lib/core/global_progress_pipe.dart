import 'dart:async';

abstract class ProgressType {}

abstract class ProgressUpdate extends ProgressType {}

abstract class ProgressFinished extends ProgressType {}

/// This global stream-sink pair allows to get progress information for long
/// running tasks, without having to shoehorn that into our logic. It is
/// general enough that it can be used for most tasks.
class GlobalProgressPipe {
  final StreamController<ProgressType> _streamController =
      StreamController.broadcast();
  static GlobalProgressPipe instance = GlobalProgressPipe._();

  GlobalProgressPipe._();

  Future<void> dispose() async {
    await _streamController.close();
  }

  /// Future completes when the [ProgressFinished] event is encountered
  Future<void> subscribeToProgress<U extends ProgressUpdate,
      F extends ProgressFinished>({
    required void Function(U progressUpdate) onUpdate,
    required void Function(F progressFinish) onFinish,
  }) async {
    bool shouldBreak = false;
    await for (final event in _streamController.stream) {
      switch (event) {
        case U():
          onUpdate(event);
        case F():
          onFinish(event);
          shouldBreak = true;
        default:
          continue;
      }
      if (shouldBreak) {
        break;
      }
    }
  }

  /// Add a [ProgressType] event to the stream.
  /// Can be an [ProgressUpdate] or [ProgressFinished] event.
  void addProgress({required ProgressType progressEvent}) {
    _streamController.add(progressEvent);
  }
}

class EmoticonsProgressUpdate extends ProgressUpdate {
  final int finishedEmoticons;
  final int totalEmoticons;
  final String message;
  EmoticonsProgressUpdate({
    required this.finishedEmoticons,
    required this.totalEmoticons,
    required this.message,
  });
}

class EmoticonsProgressFinished extends ProgressFinished {}

class EmotipicsProgressUpdate extends ProgressUpdate {
  final int finishedEmotipics;
  final int totalEmotipics;
  final String message;
  EmotipicsProgressUpdate({
    required this.finishedEmotipics,
    required this.totalEmotipics,
    required this.message,
  });
}

class EmotipicsProgressFinished extends ProgressFinished {}

class FileExtractionProgressUpdate extends ProgressUpdate {
  final int finishedFiles;
  final int? totalFiles;
  final String message;
  FileExtractionProgressUpdate({
    required this.finishedFiles,
    required this.totalFiles,
    required this.message,
  });
}

class FileExtractionProgressFinished extends ProgressFinished {}
