import 'package:emotic/core/entities/emoticon.dart';
import 'package:emotic/core/functional_list_methods.dart';
import 'emoticons_data_editor_state.dart';
import 'package:emotic/data/emoticons_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmoticonsDataEditorCubit extends Cubit<EmoticonsDataEditorState> {
  final EmoticonsRepository emoticonsRepository;
  EmoticonsDataEditorCubit({
    required this.emoticonsRepository,
  }) : super(EmoticonsDataEditorInitial()) {
    emit(EmoticonsDataEditorNotEditing());
  }

  Future<List<String>> getAllTags() async {
    return emoticonsRepository.getTags();
  }

  Future<void> loadEmoticons() async {
    final allEmoticons = await emoticonsRepository.getEmoticons(
      shouldLoadFromAsset: false,
    );
    switch (state) {
      case EmoticonsDataEditorModifyLinks(:final selectedEmoticon):
        emit(
          EmoticonsDataEditorModifyLinks(
            allEmoticons: allEmoticons,
            allTags: await getAllTags(),
            selectedEmoticon: allEmoticons.singleWhereOrNull(
              (e) => e.text == selectedEmoticon?.text,
            ),
          ),
        );
      case EmoticonsDataEditorDeleteData(
          :final selectedEmoticons,
          :final selectedTags
        ):
        final allTags = await getAllTags();
        emit(
          EmoticonsDataEditorDeleteData(
            allEmoticons: allEmoticons,
            allTags: allTags,
            selectedEmoticons: allEmoticons
                .toSet()
                .intersection(selectedEmoticons.toSet())
                .toList(),
            selectedTags:
                allTags.toSet().intersection(selectedTags.toSet()).toList(),
          ),
        );
      case EmoticonsDataEditorModifyOrder():
        emit(
          EmoticonsDataEditorModifyOrder(
            allEmoticons: allEmoticons,
            allTags: await getAllTags(),
          ),
        );
      default:
        break;
    }
  }

  Future<void> startModifyingLinks({
    required List<Emoticon> allEmoticons,
    required List<String> allTags,
  }) async {
    switch (state) {
      case EmoticonsDataEditorEditing(:final allEmoticons, :final allTags):
        // If its already in editor, use latest data. Same in below 2 functions
        emit(
          EmoticonsDataEditorModifyLinks(
            allEmoticons: allEmoticons,
            allTags: allTags,
            selectedEmoticon: null,
          ),
        );
      default:
        emit(
          EmoticonsDataEditorModifyLinks(
            allEmoticons: allEmoticons,
            allTags: allTags,
            selectedEmoticon: null,
          ),
        );
    }
  }

  Future<void> startDeleting({
    required List<Emoticon> allEmoticons,
    required List<String> allTags,
  }) async {
    switch (state) {
      case EmoticonsDataEditorEditing(:final allEmoticons, :final allTags):
        emit(
          EmoticonsDataEditorDeleteData(
            allEmoticons: allEmoticons,
            allTags: allTags,
            selectedEmoticons: const [],
            selectedTags: const [],
          ),
        );
      default:
        emit(
          EmoticonsDataEditorDeleteData(
            allEmoticons: allEmoticons,
            allTags: allTags,
            selectedEmoticons: const [],
            selectedTags: const [],
          ),
        );
    }
  }

  Future<void> startReordering({
    required List<Emoticon> allEmoticons,
    required List<String> allTags,
  }) async {
    switch (state) {
      case EmoticonsDataEditorEditing(:final allEmoticons, :final allTags):
        emit(
          EmoticonsDataEditorModifyOrder(
            allEmoticons: allEmoticons,
            allTags: allTags,
          ),
        );
      default:
        emit(
          EmoticonsDataEditorModifyOrder(
            allEmoticons: allEmoticons,
            allTags: allTags,
          ),
        );
    }
  }

  Future<void> selectEmoticon({
    required Emoticon emoticon,
  }) async {
    switch (state) {
      case EmoticonsDataEditorModifyLinks(
          :final allEmoticons,
          :final allTags,
          :final selectedEmoticon,
        ):
        emit(
          EmoticonsDataEditorModifyLinks(
            allEmoticons: allEmoticons,
            allTags: allTags,
            selectedEmoticon:
                (emoticon.text == selectedEmoticon?.text) ? null : emoticon,
          ),
        );
      case EmoticonsDataEditorDeleteData(
          :final allEmoticons,
          :final allTags,
          :final selectedEmoticons,
          :final selectedTags,
        ):
        emit(
          EmoticonsDataEditorDeleteData(
            allEmoticons: allEmoticons,
            allTags: allTags,
            selectedEmoticons: (selectedEmoticons.contains(emoticon))
                ? selectedEmoticons.removeIfExists(emoticon)
                : selectedEmoticons.addIfNotExists(emoticon),
            selectedTags: selectedTags,
          ),
        );
      default:
        break;
    }
  }

  Future<void> selectTag({
    required String tag,
  }) async {
    switch (state) {
      case EmoticonsDataEditorModifyLinks(:final selectedEmoticon)
          when selectedEmoticon != null:
        await modifyEmoticon(
          modifyEmoticon: NewOrModifyEmoticon(
            text: selectedEmoticon.text,
            emoticonTags: (selectedEmoticon.emoticonTags.contains(tag))
                ? selectedEmoticon.emoticonTags.removeIfExists(tag)
                : selectedEmoticon.emoticonTags.addIfNotExists(tag),
            oldEmoticon: selectedEmoticon,
          ),
        );
      case EmoticonsDataEditorDeleteData(
          :final allEmoticons,
          :final allTags,
          :final selectedEmoticons,
          :final selectedTags,
        ):
        emit(
          EmoticonsDataEditorDeleteData(
            allEmoticons: allEmoticons,
            allTags: allTags,
            selectedEmoticons: selectedEmoticons,
            selectedTags: (selectedTags.contains(tag))
                ? selectedTags.removeIfExists(tag)
                : selectedTags.addIfNotExists(tag),
          ),
        );
      default:
        break;
    }
  }

  Future<void> modifyEmoticon({
    required NewOrModifyEmoticon modifyEmoticon,
  }) async {
    await emoticonsRepository.saveEmoticon(
      newOrModifyEmoticon: modifyEmoticon,
    );
    await loadEmoticons();
  }

  Future<void> addNewEmoticons({
    required List<NewOrModifyEmoticon> newEmoticons,
  }) async {
    for (final newEmoticon in newEmoticons) {
      await emoticonsRepository.saveEmoticon(newOrModifyEmoticon: newEmoticon);
    }
    await loadEmoticons();
  }

  Future<void> deleteEmoticonsAndTags({
    required List<Emoticon> emoticons,
    required List<String> tags,
  }) async {
    for (final emoticon in emoticons) {
      await emoticonsRepository.deleteEmoticon(emoticon: emoticon);
    }
    for (final tag in tags) {
      await emoticonsRepository.deleteTag(tag: tag);
    }
    await loadEmoticons();
  }

  Future<void> reorderEmoticon({
    required int oldIndex,
    required int newIndex,
  }) async {
    switch (state) {
      case EmoticonsDataEditorModifyOrder(
          :final allEmoticons,
          :final allTags,
        ):
        var newEmoticonsOrder = allEmoticons.sublist(0);
        final emoticon = newEmoticonsOrder.removeAt(oldIndex);
        newEmoticonsOrder.insert(newIndex, emoticon);
        // For faster visual update
        emit(
          EmoticonsDataEditorModifyOrder(
            allEmoticons: newEmoticonsOrder,
            allTags: allTags,
          ),
        );
        await emoticonsRepository.modifyEmoticonOrder(
          emoticon: emoticon,
          newOrder: newIndex,
        );
        await loadEmoticons();
      default:
        break;
    }
  }

  Future<void> reorderTag({
    required int oldIndex,
    required int newIndex,
  }) async {
    switch (state) {
      case EmoticonsDataEditorModifyOrder(
          :final allEmoticons,
          :final allTags,
        ):
        var newTagsOrder = allTags.sublist(0);
        final tag = newTagsOrder.removeAt(oldIndex);
        newTagsOrder.insert(newIndex, tag);
        // For faster visual update
        emit(
          EmoticonsDataEditorModifyOrder(
            allEmoticons: allEmoticons,
            allTags: newTagsOrder,
          ),
        );
        await emoticonsRepository.modifyTagOrder(
          tag: tag,
          newOrder: newIndex,
        );
        await loadEmoticons();
      default:
        break;
    }
  }

  Future<void> addNewTags({required List<String> tags}) async {
    for (final tag in tags) {
      await emoticonsRepository.saveTag(tag: tag);
    }
    await loadEmoticons();
  }

  Future<void> finishEditing() async {
    emit(EmoticonsDataEditorNotEditing());
  }
}
