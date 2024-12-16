import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/tag_editor_cubit.dart';
import 'package:emotic/cubit/tag_editor_state.dart';
import 'package:emotic/widgets/add_tag_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TagEditorPage extends StatefulWidget {
  const TagEditorPage({super.key});

  @override
  State<TagEditorPage> createState() => _TagEditorPageState();
}

class _TagEditorPageState extends State<TagEditorPage> {
  Map<String, bool> tagging = {};
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
              create: (context) => TagEditorCubit(
                emoticonsRepository: sl(),
                shouldLoadFromAsset: settings.isFirstTime || settings.isUpdated,
              ),
              child: BlocBuilder<TagEditorCubit, TagEditorState>(
                builder: (context, state) {
                  switch (state) {
                    case TagEditorInitial():
                    case TagEditorLoading():
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    case TagEditorLoaded(
                        :final allEmoticons,
                        :final allTags,
                        :final selectedEmoticon
                      ):
                      tagging = Map.fromIterables(
                        allTags,
                        List.filled(
                          allTags.length,
                          false,
                        ),
                      );
                      if (selectedEmoticon != null) {
                        for (final tag in selectedEmoticon.emoticonTags) {
                          tagging[tag] = true;
                        }
                      }
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
                          title: const Text("Tag Editor"),
                          leading: DrawerButton(
                            onPressed: context.openRootScaffoldDrawer,
                          ),
                          actions: [
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: const Text("Add tag"),
                                  onTap: () async {
                                    final tag = await addNewTag(context);
                                    if (tag != null && context.mounted) {
                                      context
                                          .read<TagEditorCubit>()
                                          .addNewTag(tag: tag);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        body: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                child: ListView(
                                  // crossAxisAlignment: CrossAxisAlignment.start,
                                  children: allEmoticons
                                      .map(
                                        (e) => Card.outlined(
                                          clipBehavior: Clip.hardEdge,
                                          child: ListTile(
                                            selected: e == selectedEmoticon,
                                            selectedTileColor: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            title: Text(e.text),
                                            onTap: () {
                                              context
                                                  .read<TagEditorCubit>()
                                                  .selectEmoticon(
                                                    emoticon:
                                                        (e == selectedEmoticon)
                                                            ? null
                                                            : e,
                                                  );
                                            },
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                              Expanded(
                                child: ListView(
                                  // crossAxisAlignment: CrossAxisAlignment.start,
                                  children: tagging.keys
                                      .map(
                                        (e) => Card.outlined(
                                          clipBehavior: Clip.hardEdge,
                                          child: ListTile(
                                            selected: tagging[e] ?? false,
                                            selectedTileColor: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            title: Text(e),
                                            onTap: () {
                                              if (selectedEmoticon != null) {
                                                context
                                                    .read<TagEditorCubit>()
                                                    .updateTagForEmoticon(
                                                      emoticon:
                                                          selectedEmoticon,
                                                      tag: e,
                                                      tagChange:
                                                          (tagging[e] == true)
                                                              ? TagChange.remove
                                                              : TagChange.add,
                                                    );
                                              }
                                            },
                                          ),
                                        ),
                                      )
                                      .toList(),
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
