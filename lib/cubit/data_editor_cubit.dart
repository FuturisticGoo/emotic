import 'package:emotic/core/emoticon.dart';
import 'data_editor_state.dart';
import 'package:emotic/data/emoticons_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

extension FunctionalAdditions<E> on List<E> {
  List<E> addIfNotExists(E itemToAdd) {
    return {
      ...this,
      itemToAdd,
    }.toList();
  }

  List<E> removeIfExists(E itemToRemove) {
    return where((element) => element != itemToRemove).toList();
  }

  E? singleWhereOrNull(bool Function(E) test) {
    try {
      return singleWhere(test);
    } on StateError {
      return null;
    }
  }
}

class DataEditorCubit extends Cubit<DataEditorState> {
  final EmoticonsRepository emoticonsRepository;
  DataEditorCubit({
    required this.emoticonsRepository,
    required bool shouldLoadFromAsset,
  }) : super(DataEditorInitial()) {
    emit(DataEditorLoading());
    loadEmoticons(shouldLoadFromAsset: shouldLoadFromAsset);
  }

  Future<List<String>> getAllTags() async {
    return emoticonsRepository.getTags();
  }

  Future<void> loadEmoticons({
    required bool shouldLoadFromAsset,
  }) async {
    final allEmoticons = await emoticonsRepository.getEmoticons(
      shouldLoadFromAsset: shouldLoadFromAsset,
    );
    switch (state) {
      case DataEditorModifyLinks(:final selectedEmoticon):
        emit(
          DataEditorModifyLinks(
            allEmoticons: allEmoticons,
            allTags: await getAllTags(),
            selectedEmoticon: allEmoticons.singleWhereOrNull(
              (e) => e.text == selectedEmoticon?.text,
            ),
          ),
        );
      case DataEditorDeleteData(:final selectedEmoticons, :final selectedTags):
        emit(
          DataEditorDeleteData(
            allEmoticons: allEmoticons,
            allTags: await getAllTags(),
            selectedEmoticons: selectedEmoticons,
            selectedTags: selectedTags,
          ),
        );
      default:
        emit(
          DataEditorLoaded(
            allEmoticons: allEmoticons,
            allTags: await getAllTags(),
          ),
        );
    }
  }

  Future<void> startModifyingLinks() async {
    if (state case DataEditorLoaded(:final allEmoticons, :final allTags)) {
      emit(
        DataEditorModifyLinks(
          allEmoticons: allEmoticons,
          allTags: allTags,
          selectedEmoticon: null,
        ),
      );
    }
  }

  Future<void> startDeleting() async {
    if (state case DataEditorLoaded(:final allEmoticons, :final allTags)) {
      emit(
        DataEditorDeleteData(
          allEmoticons: allEmoticons,
          allTags: allTags,
          selectedEmoticons: const [],
          selectedTags: const [],
        ),
      );
    }
  }

  Future<void> selectEmoticon({
    required Emoticon emoticon,
  }) async {
    switch (state) {
      case DataEditorModifyLinks(
          :final allEmoticons,
          :final allTags,
          :final selectedEmoticon,
        ):
        emit(
          DataEditorModifyLinks(
            allEmoticons: allEmoticons,
            allTags: allTags,
            selectedEmoticon:
                (emoticon.text == selectedEmoticon?.text) ? null : emoticon,
          ),
        );
      case DataEditorDeleteData(
          :final allEmoticons,
          :final allTags,
          :final selectedEmoticons,
          :final selectedTags,
        ):
        emit(
          DataEditorDeleteData(
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
      case DataEditorModifyLinks(:final selectedEmoticon)
          when selectedEmoticon != null:
        await modifyEmoticon(
          emoticon: Emoticon(
            id: selectedEmoticon.id,
            text: selectedEmoticon.text,
            emoticonTags: (selectedEmoticon.emoticonTags.contains(tag))
                ? selectedEmoticon.emoticonTags.removeIfExists(tag)
                : selectedEmoticon.emoticonTags.addIfNotExists(tag),
          ),
          oldEmoticon: selectedEmoticon,
        );
      case DataEditorDeleteData(
          :final allEmoticons,
          :final allTags,
          :final selectedEmoticons,
          :final selectedTags,
        ):
        emit(
          DataEditorDeleteData(
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
    required Emoticon emoticon,
    Emoticon? oldEmoticon,
  }) async {
    await emoticonsRepository.saveEmoticon(
      emoticon: emoticon,
      oldEmoticon: oldEmoticon,
    );
    await loadEmoticons(
      shouldLoadFromAsset: false,
    );
  }

  Future<void> addNewEmoticons({
    required List<Emoticon> emoticons,
  }) async {
    emit(DataEditorLoading());
    for (final emoticon in emoticons) {
      await emoticonsRepository.saveEmoticon(emoticon: emoticon);
    }
    await loadEmoticons(shouldLoadFromAsset: false);
  }

  Future<void> deleteEmoticonsAndTags({
    required List<Emoticon> emoticons,
    required List<String> tags,
  }) async {
    emit(DataEditorLoading());
    for (final emoticon in emoticons) {
      await emoticonsRepository.deleteEmoticon(emoticon: emoticon);
    }
    for (final tag in tags) {
      await emoticonsRepository.deleteTag(tag: tag);
    }
    await loadEmoticons(
      shouldLoadFromAsset: false,
    );
  }

  void addNewTags({required List<String> tags}) async {
    emit(DataEditorLoading());
    for (final tag in tags) {
      await emoticonsRepository.saveTag(tag: tag);
    }
    await loadEmoticons(
      shouldLoadFromAsset: false,
    );
  }
}

enum TagChange { add, remove }
