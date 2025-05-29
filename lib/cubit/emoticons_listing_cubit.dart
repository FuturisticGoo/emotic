import 'package:emotic/core/emoticon.dart';
import 'package:emotic/cubit/emoticons_listing_state.dart';
import 'package:emotic/data/emoticons_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzy/fuzzy.dart';

class EmoticonsListingCubit extends Cubit<EmoticonsListingState> {
  final EmoticonsRepository emoticonsRepository;
  EmoticonsListingCubit({
    required this.emoticonsRepository,
  }) : super(EmoticonsListingInitial()) {
    loadEmoticons();
  }
  Future<void> loadEmoticons() async {
    emit(EmoticonsListingLoading());
    final allEmoticons =
        await emoticonsRepository.getEmoticons(shouldLoadFromAsset: false);
    emit(
      EmoticonsListingLoaded(
        allEmoticons: allEmoticons,
        allTags: await emoticonsRepository.getTags(),
        emoticonsToShow: allEmoticons,
      ),
    );
  }

  void saveEmoticon({
    required NewOrModifyEmoticon newOrModifyEmoticon,
  }) async {
    await emoticonsRepository.saveEmoticon(
      newOrModifyEmoticon: newOrModifyEmoticon,
    );
    loadEmoticons();
  }

  void deleteEmoticon({required Emoticon emoticon}) async {
    await emoticonsRepository.deleteEmoticon(emoticon: emoticon);
    loadEmoticons();
  }

  void searchEmoticons({required String searchTerm}) async {
    final searchTermTrimmed = searchTerm.trim();
    if (state
        case EmoticonsListingLoaded(
          :final allEmoticons,
          :final allTags,
        )) {
      if (searchTermTrimmed.isEmpty) {
        emit(
          EmoticonsListingLoaded(
            allEmoticons: allEmoticons,
            allTags: allTags,
            emoticonsToShow: allEmoticons,
          ),
        );
        return;
      }

      final fuzzy = Fuzzy(allTags);
      final searchResult = fuzzy
          .search(searchTermTrimmed, 1)
          .map(
            (e) => e.item,
          )
          .toSet();
      final result = allEmoticons.where(
        (element) {
          return element.emoticonTags
              .toSet()
              .intersection(searchResult)
              .isNotEmpty;
        },
      ).toList();
      emit(
        EmoticonsListingLoaded(
          allEmoticons: allEmoticons,
          allTags: allTags,
          emoticonsToShow: result,
        ),
      );
    }
  }
}
