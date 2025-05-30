import 'package:emotic/cubit/emoticons_data_editor_cubit.dart';
import 'package:emotic/cubit/emoticons_data_editor_state.dart';
import 'package:emotic/pages/emoticons_page_widgets/emoticon_tile.dart';
import 'package:emotic/widgets_common/tag_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmoticonsEditingView extends StatelessWidget {
  final EmoticonsDataEditorEditing state;
  final String emoticonsListKey = "emoticonsListKey";
  final String tagsListKey = "tagsListKey";
  const EmoticonsEditingView({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                switch (state) {
                  EmoticonsDataEditorModifyLinks() =>
                    "Select an emoticon to modify its tags",
                  EmoticonsDataEditorDeleteData() =>
                    "Select the emoticons and tags you wish to delete",
                  EmoticonsDataEditorModifyOrder() =>
                    "Drag the handle to reorder emoticons or tags",
                },
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: state is EmoticonsDataEditorModifyOrder
                      ? ReorderableListView(
                          key: PageStorageKey(emoticonsListKey),
                          buildDefaultDragHandles: false,
                          onReorder: (oldIndex, newIndex) async {
                            if (oldIndex < newIndex) {
                              // removing the item at oldIndex will shorten the list by 1.
                              newIndex -= 1;
                            }
                            await context
                                .read<EmoticonsDataEditorCubit>()
                                .reorderEmoticon(
                                  oldIndex: oldIndex,
                                  newIndex: newIndex,
                                );
                          },
                          // crossAxisAlignment: CrossAxisAlignment.start,
                          children: state.allEmoticons.asMap().entries.map(
                            (e) {
                              return EmoticonTile(
                                key: Key("emoticon-${e.value.id}"),
                                isSelected: false,
                                emoticon: e.value,
                                onTap: () {},
                                trailing: ReorderableDragStartListener(
                                  key: ValueKey(
                                    e.key,
                                  ),
                                  index: e.key,
                                  child: const Icon(
                                    Icons.drag_handle,
                                  ),
                                ),
                              );
                            },
                          ).toList(),
                        )
                      : ListView(
                          key: PageStorageKey(emoticonsListKey),
                          children: state.allEmoticons.map(
                            (e) {
                              final isSelected = switch (state) {
                                EmoticonsDataEditorModifyLinks(
                                  :final selectedEmoticon
                                ) =>
                                  e.text == selectedEmoticon?.text,
                                EmoticonsDataEditorDeleteData(
                                  :final selectedEmoticons
                                ) =>
                                  selectedEmoticons.contains(e),
                                _ => false,
                              };
                              return EmoticonTile(
                                key: Key("emoticon-${e.id}"),
                                isSelected: isSelected,
                                emoticon: e,
                                onTap: () async {
                                  await context
                                      .read<EmoticonsDataEditorCubit>()
                                      .selectEmoticon(
                                        emoticon: e,
                                      );
                                },
                                trailing: null,
                              );
                            },
                          ).toList(),
                        ),
                ),
                Expanded(
                  child: state is EmoticonsDataEditorModifyOrder
                      ? ReorderableListView(
                          key: PageStorageKey(tagsListKey),
                          buildDefaultDragHandles: false,
                          onReorder: (oldIndex, newIndex) async {
                            if (oldIndex < newIndex) {
                              // removing the item at oldIndex will shorten the list by 1.
                              newIndex -= 1;
                            }
                            await context
                                .read<EmoticonsDataEditorCubit>()
                                .reorderTag(
                                  oldIndex: oldIndex,
                                  newIndex: newIndex,
                                );
                          },
                          // crossAxisAlignment: CrossAxisAlignment.start,
                          children: state.allTags.asMap().entries.map(
                            (e) {
                              return TagTile(
                                key: Key("tag-${e.value}"),
                                isSelected: false,
                                tag: e.value,
                                onTap: () {},
                                trailing: ReorderableDragStartListener(
                                  key: ValueKey(e.key),
                                  index: e.key,
                                  child: const Icon(
                                    Icons.drag_handle,
                                  ),
                                ),
                              );
                            },
                          ).toList(),
                        )
                      : ListView(
                          key: PageStorageKey(tagsListKey),
                          // crossAxisAlignment: CrossAxisAlignment.start,
                          children: state.allTags.map(
                            (e) {
                              final isSelected = switch (state) {
                                EmoticonsDataEditorModifyLinks(
                                  :final selectedEmoticon
                                )
                                    when selectedEmoticon != null =>
                                  selectedEmoticon.emoticonTags.contains(e),
                                EmoticonsDataEditorDeleteData(
                                  :final selectedTags
                                ) =>
                                  selectedTags.contains(e),
                                _ => false,
                              };
                              return TagTile(
                                isSelected: isSelected,
                                tag: e,
                                onTap: () async {
                                  await context
                                      .read<EmoticonsDataEditorCubit>()
                                      .selectTag(
                                        tag: e,
                                      );
                                },
                                trailing: null,
                              );
                            },
                          ).toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
