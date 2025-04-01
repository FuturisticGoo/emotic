part of 'settings_cubit.dart';

sealed class SettingsState {}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState with EquatableMixin {
  final String? snackBarMessage;
  final String? alertMessage;

  SettingsLoaded({this.snackBarMessage, this.alertMessage});

  @override
  List<Object?> get props => [snackBarMessage, alertMessage];
}