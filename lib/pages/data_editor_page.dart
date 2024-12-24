import 'package:emotic/core/emoticon.dart';
import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/data_editor_cubit.dart';
import 'package:emotic/cubit/data_editor_state.dart';
import 'package:emotic/widgets/delete_confirmation.dart';
import 'package:emotic/widgets/read_list_of_string_from_user.dart';
import 'package:emotic/widgets/show_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    return BlocBuilder<GlobalSettingsCubit, GlobalSettingsState>(
      builder: (context, state) {
        switch (state) {
          case GlobalSettingsInitial():
          case GlobalSettingsLoading():
            return const Center(
              child: CircularProgressIndicator(),
            );
          case GlobalSettingsLoaded(:final settings):
            return BlocProvider(
              create: (context) => DataEditorCubit(
                emoticonsRepository: sl(),
                shouldLoadFromAsset: settings.shouldReload,
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
                      // tagging = Map.fromIterables(
                      //   allTags,
                      //   List.filled(
                      //     allTags.length,
                      //     false,
                      //   ),
                      // );
                      // if (selectedEmoticon != null) {
                      //   for (final tag in selectedEmoticon.emoticonTags) {
                      //     tagging[tag] = true;
                      //   }
                      // }
                      //? Should I do sorting?
                      // var selectedTags = tagging.keys
                      //     .where(
                      //       (element) => tagging[element] ?? false,
                      //     )
                      //     .toList();
                      // var unselectedTags = tagging.keys
                      //     .toSet()
                      //     .difference(selectedTags.toSet())
                      //     .toList();
                      // selectedTags.sort();
                      // unselectedTags.sort();

                      // tagging = {
                      //   ...Map.fromIterables(
                      //     selectedTags,
                      //     List.filled(selectedTags.length, true),
                      //   ),
                      //   ...Map.fromIterables(
                      //     unselectedTags,
                      //     List.filled(unselectedTags.length, false),
                      //   ),
                      // };
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
                                            emoticons: emoticonsStringList
                                                .map(
                                                  (e) => Emoticon(
                                                    id: null,
                                                    text: e,
                                                    emoticonTags: const [],
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
                                      child: ListView(
                                        key: PageStorageKey(emoticonsListKey),
                                        // crossAxisAlignment: CrossAxisAlignment.start,
                                        children: allEmoticons.map((e) {
                                          final isSelected = switch (state) {
                                            DataEditorModifyLinks(
                                              :final selectedEmoticon
                                            ) =>
                                              e.text == selectedEmoticon?.text,
                                            DataEditorDeleteData(
                                              :final selectedEmoticons
                                            ) =>
                                              selectedEmoticons.contains(e),
                                            _ => false,
                                          };
                                          return Card.outlined(
                                            clipBehavior: Clip.hardEdge,
                                            child: ListTile(
                                              selected: isSelected,
                                              selectedTileColor:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer,
                                              title: Text(e.text),
                                              onTap: () {
                                                context
                                                    .read<DataEditorCubit>()
                                                    .selectEmoticon(
                                                      emoticon: e,
                                                    );
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView(
                                        key: PageStorageKey(tagsListKey),
                                        // crossAxisAlignment: CrossAxisAlignment.start,
                                        children: allTags.map(
                                          (e) {
                                            final isSelected = switch (state) {
                                              DataEditorModifyLinks(
                                                :final selectedEmoticon
                                              )
                                                  when selectedEmoticon !=
                                                      null =>
                                                selectedEmoticon.emoticonTags
                                                    .contains(e),
                                              DataEditorDeleteData(
                                                :final selectedTags
                                              ) =>
                                                selectedTags.contains(e),
                                              _ => false,
                                            };
                                            return Card.outlined(
                                              clipBehavior: Clip.hardEdge,
                                              child: ListTile(
                                                selected: isSelected,
                                                selectedTileColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primaryContainer,
                                                title: Text(e),
                                                onTap: () {
                                                  context
                                                      .read<DataEditorCubit>()
                                                      .selectTag(
                                                        tag: e,
                                                      );
                                                },
                                              ),
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
