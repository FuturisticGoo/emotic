part of 'emotipics_cubit.dart';

sealed class EmotipicsListingState {
  const EmotipicsListingState();
}

class EmotipicsListingInitial extends EmotipicsListingState {}

class EmotipicsListingLoading extends EmotipicsListingState {}

class EmotipicsListingLoaded extends EmotipicsListingState with EquatableMixin {
  final List<EmoticImage> images;
  final Map<Uri, Uint8List> visibleImageData;
  const EmotipicsListingLoaded({
    required this.images,
    required this.visibleImageData,
  });
  @override
  List<Object?> get props => [
        images,
        visibleImageData,
      ];
}

class EmotipicsListingError extends EmotipicsListingState {}
