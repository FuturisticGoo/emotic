part of 'settings_cubit.dart';

sealed class SettingsState {
  const SettingsState();
}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsProgressBar extends SettingsState with EquatableMixin {
  final int currentProgress;
  final int? outOf;
  final String message;
  const SettingsProgressBar({
    required this.currentProgress,
    required this.outOf,
    required this.message,
  });
  @override
  List<Object?> get props => [currentProgress, outOf, message];
}

class SettingsLoaded extends SettingsState with EquatableMixin {
  final String? snackBarMessage;
  final String? alertMessage;

  SettingsLoaded({this.snackBarMessage, this.alertMessage});

  @override
  List<Object?> get props => [snackBarMessage, alertMessage];
}
