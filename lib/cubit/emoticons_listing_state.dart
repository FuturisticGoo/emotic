import 'package:emotic/core/entities/emoticon.dart';
import 'package:equatable/equatable.dart';

sealed class EmoticonsListingState extends Equatable {}

class EmoticonsListingInitial extends EmoticonsListingState {
  @override
  List<Object?> get props => [];
}

class EmoticonsListingLoading extends EmoticonsListingState {
  @override
  List<Object?> get props => [];
}

class EmoticonsListingLoaded extends EmoticonsListingState {
  final List<Emoticon> allEmoticons;
  final List<String> allTags;
  final List<Emoticon> emoticonsToShow;
  EmoticonsListingLoaded({
    required this.allEmoticons,
    required this.allTags,
    required this.emoticonsToShow,
  });
  @override
  List<Object?> get props => [allEmoticons, emoticonsToShow, allTags];
}
