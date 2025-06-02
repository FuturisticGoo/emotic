import 'package:emotic/core/global_progress_pipe.dart';
import 'package:emotic/data/emoticons_repository.dart';
import 'package:emotic/data/image_repository.dart';
import 'package:emotic/data/settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final EmoticonsRepository emoticonsRepository;
  final ImageRepository imageRepository;
  final SettingsRepository settingsRepository;
  final GlobalProgressPipe globalProgressPipe;
  SettingsCubit({
    required this.settingsRepository,
    required this.emoticonsRepository,
    required this.imageRepository,
    required this.globalProgressPipe,
  }) : super(SettingsInitial()) {
    emit(SettingsLoading());
    emit(SettingsLoaded());
  }

  void _safeEmit(SettingsState settingsState) {
    if (!isClosed) {
      emit(settingsState);
    }
  }

  Future<void> loadEmoticonsFromAsset() async {
    emit(SettingsLoading());
    await emoticonsRepository.getEmoticons(shouldLoadFromAsset: true);
    emit(SettingsLoaded(
      snackBarMessage: "Restored all emoticons",
    ));
  }

  Future<void> clearAllData() async {
    emit(SettingsLoading());
    await emoticonsRepository.clearAllData();
    await imageRepository.clearAllData();
    emit(SettingsLoaded(snackBarMessage: "Cleared data"));
  }

  Future<void> exportData() async {
    emit(SettingsLoading());
    _subscribeToEmoticonProgress();
    _subscribeToEmotipicsProgress();
    final result = await settingsRepository.exportToFile();
    switch (result) {
      case Left(:final value):
        emit(SettingsLoaded(alertMessage: "Error exporting: ${value.message}"));
      case Right():
        emit(SettingsLoaded(snackBarMessage: "Export successful"));
    }
  }

  Future<void> importData() async {
    emit(SettingsLoading());
    _subscribeToEmoticonProgress();
    _subscribeToEmotipicsProgress();
    _subscribeToFileExtractionProgress();
    final result = await settingsRepository.importFromFile();
    switch (result) {
      case Left(:final value):
        emit(SettingsLoaded(alertMessage: "Error importing: ${value.message}"));
      case Right():
        emit(SettingsLoaded(snackBarMessage: "Import successful"));
    }
  }

  void _subscribeToEmoticonProgress() async {
    globalProgressPipe.subscribeToProgress<EmoticonsProgressUpdate,
        EmoticonsProgressFinished>(
      onUpdate: (progressUpdate) {
        _safeEmit(
          SettingsProgressBar(
            currentProgress: progressUpdate.finishedEmoticons,
            outOf: progressUpdate.totalEmoticons,
            message: progressUpdate.message,
          ),
        );
      },
      onFinish: (progressFinish) {
        _safeEmit(
          SettingsLoading(),
        );
      },
    );
  }

  void _subscribeToEmotipicsProgress() async {
    globalProgressPipe.subscribeToProgress<EmotipicsProgressUpdate,
        EmotipicsProgressFinished>(
      onUpdate: (progressUpdate) {
        _safeEmit(
          SettingsProgressBar(
            currentProgress: progressUpdate.finishedEmotipics,
            outOf: progressUpdate.totalEmotipics,
            message: progressUpdate.message,
          ),
        );
      },
      onFinish: (progressFinish) {
        _safeEmit(
          SettingsLoading(),
        );
      },
    );
  }

  void _subscribeToFileExtractionProgress() async {
    globalProgressPipe.subscribeToProgress<FileExtractionProgressUpdate,
        FileExtractionProgressFinished>(
      onUpdate: (progressUpdate) {
        _safeEmit(
          SettingsProgressBar(
            currentProgress: progressUpdate.finishedFiles,
            outOf: progressUpdate.totalFiles,
            message: progressUpdate.message,
          ),
        );
      },
      onFinish: (progressFinish) {
        _safeEmit(
          SettingsLoading(),
        );
      },
    );
  }
}
