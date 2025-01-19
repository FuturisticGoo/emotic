import 'package:emotic/core/emoticon.dart';
import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/core/routes.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/data_editor_cubit.dart';
import 'package:emotic/cubit/data_editor_state.dart';
import 'package:emotic/widgets/delete_confirmation.dart';
import 'package:emotic/widgets/emoticon_tile.dart';
import 'package:emotic/widgets/read_list_of_string_from_user.dart';
import 'package:emotic/widgets/show_snackbar.dart';
import 'package:emotic/widgets/tag_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DataEditorPage extends StatefulWidget {
  const DataEditorPage({super.key});

  @override
  State<DataEditorPage> createState() => _DataEditorPageState();
}

class _DataEditorPageState extends State<DataEditorPage> {
  final String emoticonsListKey = "emoticonsListKey";
  final String tagsListKey = "tagsListKey";

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GlobalSettingsCubit, GlobalSettingsState>(
      listener: (context, state) {
        if (state case GlobalSettingsLoaded(:final settings)) {
          getLogger().config("Is Updated: ${settings.isUpdated}");
          getLogger().config("Is First Time: ${settings.isFirstTime}");
          if (settings.shouldReload) {
            getLogger().config("Redirecting to app update page");
            context.go(Routes.updatingPage);
          }
        }
      },
      buildWhen: (previous, current) {
        if (current case GlobalSettingsLoaded(:final settings)
            when settings.shouldReload) {
          // If we need to reload the settings, we shouldn't trigger
          // building EmoticonsListingCubit becuase it will try to load and emit
          // emoticons, but the screen would have redirected to updating page,
          // so it will be an error
          return false;
        } else {
          return previous != current;
        }
      },
      builder: (context, state) {
        switch (state) {
          case GlobalSettingsInitial():
          case GlobalSettingsLoading():
            return const Center(
              child: CircularProgressIndicator(),
            );
          case GlobalSettingsLoaded():
            return BlocProvider(
              create: (context) => DataEditorCubit(
                emoticonsRepository: sl(),
              ),
              child: BlocBuilder<DataEditorCubit, DataEditorState>(
                builder: (context, state) {
                  switch (state) {
                    case DataEditorInitial():
                    case DataEditorLoading():
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    case DataEditorLoaded(
                        :final allEmoticons,
                        :final allTags,
                      ):
                      return Scaffold(
                        appBar: AppBar(
                          title: const Text("Data Editor"),
                          leading: DrawerButton(
                            onPressed: context.openRootScaffoldDrawer,
                          ),
                          actions: [
                            ...(state is DataEditorDeleteData)
                                ? [
                                    IconButton(
                                      onPressed: () async {
                                        if (state
                                            case DataEditorDeleteData(
                                              :final selectedEmoticons,
                                              :final selectedTags
                                            )) {
                                          final choice =
                                              await confirmDeletionDialog(
                                                  context,
                                                  titleText:
                                                      "Delete ${selectedEmoticons.length} emoticons and ${selectedTags.length} tags?");
                                          if (choice == true &&
                                              context.mounted) {
                                            await context
                                                .read<DataEditorCubit>()
                                                .deleteEmoticonsAndTags(
                                                  emoticons: selectedEmoticons,
                                                  tags: selectedTags,
                                                );
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.delete),
                                    ),
                                  ]
                                : [],
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: const Text("Add emoticons"),
                                  onTap: () async {
                                    final emoticonsStringList =
                                        await readListOfStringFromUser(
                                      context,
                                      titleText: "Add Emoticons",
                                      textLabel: "Emoticons",
                                      textHint: "One emoticon per line",
                                    );
                                    if (emoticonsStringList != null &&
                                        context.mounted) {
                                      context
                                          .read<DataEditorCubit>()
                                          .addNewEmoticons(
                                            newEmoticons: emoticonsStringList
                                                .map(
                                                  (e) => NewOrModifyEmoticon(
                                                    text: e,
                                                    emoticonTags: const [],
                                                    oldEmoticon: null,
                                                  ),
                                                )
                                                .toList(),
                                          );
                                      showSnackBar(
                                        context,
                                        text:
                                            "Added ${emoticonsStringList.length} emoticons",
                                      );
                                    }
                                  },
                                ),
                                PopupMenuItem(
                                  child: const Text("Add tags"),
                                  onTap: () async {
                                    final tags = await readListOfStringFromUser(
                                      context,
                                      titleText: "Add Tags",
                                      textLabel: "Tags",
                                      textHint: "One tag per line",
                                    );
                                    if (tags != null && context.mounted) {
                                      context
                                          .read<DataEditorCubit>()
                                          .addNewTags(tags: tags);
                                      showSnackBar(
                                        context,
                                        text: "Added ${tags.length} tags",
                                      );
                                    }
                                  },
                                ),
                                PopupMenuItem(
                                  child: const Text("Edit emoticon->tag link"),
                                  onTap: () async {
                                    await context
                                        .read<DataEditorCubit>()
                                        .startModifyingLinks();
                                  },
                                ),
                                PopupMenuItem(
                                  child: const Text("Delete emoticons/tags"),
                                  onTap: () async {
                                    await context
                                        .read<DataEditorCubit>()
                                        .startDeleting();
                                  },
                                ),
                                PopupMenuItem(
                                  child: const Text("Reorder emoticons/tags"),
                                  onTap: () async {
                                    await context
                                        .read<DataEditorCubit>()
                                        .startReordering();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        body: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(
                                    switch (state) {
                                      DataEditorModifyLinks() =>
                                        "Select an emoticon to modify its tags",
                                      DataEditorDeleteData() =>
                                        "Select the emoticons and tags you wish to delete",
                                      DataEditorModifyOrder() =>
                                        "Drag the handle to reorder emoticons or tags",
                                      DataEditorLoaded() =>
                                        "Choose an option from the menu"
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Expanded(
                                      child: state is DataEditorModifyOrder
                                          ? ReorderableListView(
                                              key: PageStorageKey(
                                                  emoticonsListKey),
                                              buildDefaultDragHandles: true,
                                              onReorder:
                                                  (oldIndex, newIndex) async {
                                                if (oldIndex < newIndex) {
                                                  // removing the item at oldIndex will shorten the list by 1.
                                                  newIndex -= 1;
                                                }
                                                await context
                                                    .read<DataEditorCubit>()
                                                    .reorderEmoticon(
                                                      oldIndex: oldIndex,
                                                      newIndex: newIndex,
                                                    );
                                              },
                                              // crossAxisAlignment: CrossAxisAlignment.start,
                                              children: allEmoticons.map(
                                                (e) {
                                                  return EmoticonTile(
                                                    key:
                                                        Key("emoticon-${e.id}"),
                                                    isSelected: false,
                                                    emoticon: e,
                                                    onTap: () {},
                                                  );
                                                },
                                              ).toList(),
                                            )
                                          : ListView(
                                              key: PageStorageKey(
                                                  emoticonsListKey),
                                              children: allEmoticons.map(
                                                (e) {
                                                  final isSelected =
                                                      switch (state) {
                                                    DataEditorModifyLinks(
                                                      :final selectedEmoticon
                                                    ) =>
                                                      e.text ==
                                                          selectedEmoticon
                                                              ?.text,
                                                    DataEditorDeleteData(
                                                      :final selectedEmoticons
                                                    ) =>
                                                      selectedEmoticons
                                                          .contains(e),
                                                    _ => false,
                                                  };
                                                  return EmoticonTile(
                                                    key:
                                                        Key("emoticon-${e.id}"),
                                                    isSelected: isSelected,
                                                    emoticon: e,
                                                    onTap: () async {
                                                      await context
                                                          .read<
                                                              DataEditorCubit>()
                                                          .selectEmoticon(
                                                            emoticon: e,
                                                          );
                                                    },
                                                  );
                                                },
                                              ).toList(),
                                            ),
                                    ),
                                    Expanded(
                                      child: state is DataEditorModifyOrder
                                          ? ReorderableListView(
                                              key: PageStorageKey(tagsListKey),
                                              buildDefaultDragHandles: true,
                                              onReorder:
                                                  (oldIndex, newIndex) async {
                                                if (oldIndex < newIndex) {
                                                  // removing the item at oldIndex will shorten the list by 1.
                                                  newIndex -= 1;
                                                }
                                                await context
                                                    .read<DataEditorCubit>()
                                                    .reorderTag(
                                                      oldIndex: oldIndex,
                                                      newIndex: newIndex,
                                                    );
                                              },
                                              // crossAxisAlignment: CrossAxisAlignment.start,
                                              children: allTags.map(
                                                (e) {
                                                  return TagTile(
                                                    key: Key("tag-$e"),
                                                    isSelected: false,
                                                    tag: e,
                                                    onTap: () {},
                                                  );
                                                },
                                              ).toList(),
                                            )
                                          : ListView(
                                              key: PageStorageKey(tagsListKey),
                                              // crossAxisAlignment: CrossAxisAlignment.start,
                                              children: allTags.map(
                                                (e) {
                                                  final isSelected =
                                                      switch (state) {
                                                    DataEditorModifyLinks(
                                                      :final selectedEmoticon
                                                    )
                                                        when selectedEmoticon !=
                                                            null =>
                                                      selectedEmoticon
                                                          .emoticonTags
                                                          .contains(e),
                                                    DataEditorDeleteData(
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
                                                          .read<
                                                              DataEditorCubit>()
                                                          .selectTag(
                                                            tag: e,
                                                          );
                                                    },
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
                        ),
                      );
                  }
                },
              ),
            );
        }
      },
    );
  }
}
