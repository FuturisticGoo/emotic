import 'package:emotic/data/emoticons_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final EmoticonsRepository emoticonsRepository;
  SettingsCubit({
    required this.emoticonsRepository,
  }) : super(SettingsInitial()) {
    emit(SettingsLoading());
    emit(SettingsLoaded());
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
    emit(SettingsLoaded(snackBarMessage: "Cleared data"));
  }

  Future<void> exportData() async {
    emit(SettingsLoading());
    final result = await emoticonsRepository.exportToFile();
    if (result.isError) {
      emit(SettingsLoaded(alertMessage: "Error exporting: ${result.asError!.error}"));
    } else {
      emit(SettingsLoaded(snackBarMessage: "Export successful"));
    }
  }

  Future<void> importData() async {
    emit(SettingsLoading());
    final result = await emoticonsRepository.importFromFile();
    if (result.isError) {
      emit(SettingsLoaded(alertMessage: "Error reading data: ${result.asError!.error}"));
    } else {
      emit(SettingsLoaded(snackBarMessage: "Import successful"));
    }
  }
}
