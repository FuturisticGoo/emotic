part of 'settings_cubit.dart';

sealed class SettingsState {}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState with EquatableMixin {
  final String? snackBarMessage;
  SettingsLoaded({
    this.snackBarMessage,
  });
  @override
  List<Object?> get props => [
        snackBarMessage,
      ];
}
