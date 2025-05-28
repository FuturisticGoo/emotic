part of 'emotipics_cubit.dart';

sealed class EmotipicsListingState {
  const EmotipicsListingState();
}

class EmotipicsListingInitial extends EmotipicsListingState {}

class EmotipicsListingLoading extends EmotipicsListingState {}

class EmotipicsListingLoaded extends EmotipicsListingState with EquatableMixin {
  final List<EmoticImage> images;
  final Map<Uri, ImageRepr> visibleImageData;
  final List<String> allTags;
  final String? snackBarMessage;
  const EmotipicsListingLoaded({
    required this.images,
    required this.visibleImageData,
    required this.allTags,
    this.snackBarMessage,
  });
  @override
  List<Object?> get props => [
        images,
        visibleImageData,
        allTags,
        snackBarMessage,
      ];
}

class EmotipicsListingError extends EmotipicsListingState {}
