part of 'fancy_text_cubit.dart';

sealed class FancyTextState {
  const FancyTextState();
}

class FancyTextInitial extends FancyTextState {}

class FancyTextLoading extends FancyTextState {}

class FancyTextLoaded extends FancyTextState with EquatableMixin {
  final String inputText;
  final List<FancyTextTransform> textTransforms;
  FancyTextLoaded({
    required this.inputText,
    required this.textTransforms,
  });

  @override
  List<Object?> get props => [
        inputText,
        textTransforms,
      ];
}
