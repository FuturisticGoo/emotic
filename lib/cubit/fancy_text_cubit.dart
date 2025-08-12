import 'package:emotic/core/entities/fancy_text_transform.dart';
import 'package:emotic/data/fancy_text_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'fancy_text_state.dart';

class FancyTextCubit extends Cubit<FancyTextState> {
  final FancyTextRepository fancyTextRepository;
  FancyTextCubit({
    required this.fancyTextRepository,
  }) : super(FancyTextInitial()) {
    emit(FancyTextLoading());
    loadTextTransforms();
  }

  Future<void> loadTextTransforms() async {
    final textTransforms = await fancyTextRepository.getFancyTextTransforms();
    emit(
      FancyTextLoaded(
        inputText: "",
        textTransforms: textTransforms,
      ),
    );
  }

  Future<void> changeText({required String text}) async {
    if (state case FancyTextLoaded(:final textTransforms)) {
      emit(
        FancyTextLoaded(
          inputText: text,
          textTransforms: textTransforms,
        ),
      );
    }
  }
}
