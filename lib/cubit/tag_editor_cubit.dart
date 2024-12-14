import 'package:emotic/core/emoticon.dart';
import 'tag_editor_state.dart';
import 'package:emotic/data/emoticons_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TagEditorCubit extends Cubit<TagEditorState> {
  final EmoticonsRepository emoticonsRepository;
  TagEditorCubit({
    required this.emoticonsRepository,
    required bool shouldLoadFromAsset,
  }) : super(TagEditorInitial()) {
    loadEmoticons(shouldLoadFromAsset: shouldLoadFromAsset);
  }

  Future<List<String>> getAllTags() async {
    return emoticonsRepository.getTags();
  }

  Future<void> loadEmoticons({
    required bool shouldLoadFromAsset,
    Emoticon? selectedEmoticon,
  }) async {
    emit(TagEditorLoading());
    final allEmoticons = await emoticonsRepository.getEmoticons(
        shouldLoadFromAsset: shouldLoadFromAsset);
    emit(
      TagEditorLoaded(
        allEmoticons: allEmoticons,
        // allTags: _getAllTags(allEmoticons),
        allTags: await getAllTags(),
        selectedEmoticon: selectedEmoticon,
      ),
    );
  }

  Future<void> selectEmoticon({required Emoticon? emoticon}) async {
    final currentState = state;
    if (currentState is TagEditorLoaded) {
      emit(TagEditorLoaded(
        allEmoticons: currentState.allEmoticons,
        allTags: currentState.allTags,
        selectedEmoticon: emoticon,
      ));
    }
  }

  Future<void> saveEmoticon({
    required Emoticon emoticon,
    Emoticon? oldEmoticon,
  }) async {
    await emoticonsRepository.saveEmoticon(
      emoticon: emoticon,
      oldEmoticon: oldEmoticon,
    );
    await loadEmoticons(
      shouldLoadFromAsset: false,
      selectedEmoticon: emoticon,
    );
  }

  void deleteEmoticon({required Emoticon emoticon}) async {
    await emoticonsRepository.deleteEmoticon(emoticon: emoticon);
    await loadEmoticons(shouldLoadFromAsset: false);
  }

  void saveTag({
    required String tag,
    required TagChange tagChange,
  }) async {
    final currentState = state;
    if (currentState case TagEditorLoaded(:final selectedEmoticon)) {
      if (selectedEmoticon != null) {
        await saveEmoticon(
          emoticon: Emoticon(
            id: selectedEmoticon.id,
            text: selectedEmoticon.text,
            emoticonTags: (tagChange == TagChange.add)
                ? [...selectedEmoticon.emoticonTags, tag]
                : selectedEmoticon.emoticonTags
                    .where((element) => element != tag)
                    .toList(),
          ),
          oldEmoticon: selectedEmoticon,
        );
      }
    }
  }
}

enum TagChange { add, remove }
