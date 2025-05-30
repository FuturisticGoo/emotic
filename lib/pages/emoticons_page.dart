import 'package:emotic/core/emoticon.dart';
import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/core/routes.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/emoticons_data_editor_cubit.dart';
import 'package:emotic/cubit/emoticons_data_editor_state.dart';
import 'package:emotic/cubit/emoticons_listing_cubit.dart';
import 'package:emotic/cubit/emoticons_listing_state.dart';
import 'package:emotic/widgets/blank_icon_space.dart';
import 'package:emotic/widgets/copyable_emoticon.dart';
import 'package:emotic/widgets/delete_confirmation.dart';
import 'package:emotic/widgets/emoticon_tile.dart';
import 'package:emotic/widgets/read_list_of_string_from_user.dart';
import 'package:emotic/widgets/search_bar.dart';
import 'package:emotic/widgets/show_message.dart';
import 'package:emotic/widgets/tag_tile.dart';
import 'package:emotic/widgets/update_emoticon_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class EmoticonsPage extends StatefulWidget {
  const EmoticonsPage({super.key});

  @override
  State<EmoticonsPage> createState() => _EmoticonsPageState();
}

class _EmoticonsPageState extends State<EmoticonsPage> {
  final TextEditingController controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

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
              child: CircularProgressIndicator.adaptive(),
            );
          case GlobalSettingsLoaded(:final settings):
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (context) => EmoticonsListingCubit(
                    emoticonsRepository: sl(),
                  ),
                ),
                BlocProvider(
                  create: (context) => EmoticonsDataEditorCubit(
                    emoticonsRepository: sl(),
                  ),
                ),
              ],
              child: BlocListener<EmoticonsDataEditorCubit,
                  EmoticonsDataEditorState>(
                listener: (context, state) async {
                  await context.read<EmoticonsListingCubit>().loadEmoticons();
                },
                listenWhen: (previous, current) {
                  return previous is EmoticonsDataEditorEditing &&
                      current is EmoticonsDataEditorNotEditing;
                },
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text("Emoticons"),
                    leading: DrawerButton(
                      onPressed: context.openRootScaffoldDrawer,
                    ),
                    actions: [
                      BlocBuilder<EmoticonsDataEditorCubit,
                          EmoticonsDataEditorState>(
                        builder: (context, state) {
                          if (state case EmoticonsDataEditorEditing()) {
                            return IconButton(
                              onPressed: () async {
                                context
                                    .read<EmoticonsDataEditorCubit>()
                                    .finishEditing();
                              },
                              icon: Icon(Icons.check),
                            );
                          } else {
                            return SizedBox.shrink();
                          }
                        },
                      ),
                      BlocBuilder<EmoticonsDataEditorCubit,
                          EmoticonsDataEditorState>(
                        builder: (context, state) {
                          if (state
                              case EmoticonsDataEditorDeleteData(
                                :final selectedEmoticons,
                                :final selectedTags
                              )) {
                            return IconButton(
                              onPressed: () async {
                                final choice = await confirmDeletionDialog(
                                    context,
                                    titleText:
                                        "Delete ${selectedEmoticons.length}"
                                        " emoticons and ${selectedTags.length}"
                                        " tags?");
                                if (choice == true && context.mounted) {
                                  await context
                                      .read<EmoticonsDataEditorCubit>()
                                      .deleteEmoticonsAndTags(
                                        emoticons: selectedEmoticons,
                                        tags: selectedTags,
                                      );
                                }
                              },
                              icon: Icon(Icons.delete),
                            );
                          } else {
                            return SizedBox.shrink();
                          }
                        },
                      ),
                      BlocBuilder<EmoticonsListingCubit, EmoticonsListingState>(
                        builder: (context, state) {
                          return PopupMenuButton(
                            itemBuilder: (context) {
                              switch (state) {
                                case EmoticonsListingLoaded(
                                    :final allEmoticons,
                                    :final allTags
                                  ):
                                  return [
                                    PopupMenuItem(
                                      child: ListTile(
                                        leading: Icon(Icons.add),
                                        title: const Text("Add Emoticon"),
                                      ),
                                      onTap: () async {
                                        if (state
                                            case EmoticonsListingLoaded(
                                              :final allTags
                                            )) {
                                          final result =
                                              await showModalBottomSheet<
                                                  BottomSheetResult?>(
                                            context: context,
                                            isScrollControlled: true,
                                            builder: (context) {
                                              return UpdateEmoticonBottomSheet(
                                                allTags: allTags,
                                                isEditMode: false,
                                                newOrModifyEmoticon:
                                                    NewOrModifyEmoticon
                                                        .newEmoticon(),
                                              );
                                            },
                                          );
                                          switch (result) {
                                            case AddEmoticon(
                                                :final newOrModifyEmoticon
                                              ):
                                              if (context.mounted) {
                                                await context
                                                    .read<
                                                        EmoticonsDataEditorCubit>()
                                                    .addNewEmoticons(
                                                  newEmoticons: [
                                                    newOrModifyEmoticon
                                                  ],
                                                );
                                              }
                                              if (context.mounted) {
                                                await context
                                                    .read<
                                                        EmoticonsListingCubit>()
                                                    .loadEmoticons();
                                              }

                                            default:
                                              break;
                                          }
                                        }
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: ListTile(
                                        leading: BlankIconSpace(),
                                        title: const Text("Add Multiple"),
                                      ),
                                      onTap: () async {
                                        final emoticonsStringList =
                                            await readEmoticons(context);

                                        if (emoticonsStringList != null &&
                                            context.mounted) {
                                          await context
                                              .read<EmoticonsDataEditorCubit>()
                                              .addNewEmoticons(
                                                newEmoticons:
                                                    emoticonsStringList
                                                        .map(
                                                          (e) =>
                                                              NewOrModifyEmoticon(
                                                            text: e,
                                                            emoticonTags: const [],
                                                            oldEmoticon: null,
                                                          ),
                                                        )
                                                        .toList(),
                                              );
                                          if (context.mounted) {
                                            await context
                                                .read<EmoticonsListingCubit>()
                                                .loadEmoticons();
                                          }
                                          if (context.mounted) {
                                            showSnackBar(
                                              context,
                                              text:
                                                  "Added ${emoticonsStringList.length}"
                                                  " emoticons",
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: ListTile(
                                        leading: BlankIconSpace(),
                                        title: const Text("Add Tag(s)"),
                                      ),
                                      onTap: () async {
                                        final tags = await readTags(context);
                                        if (tags != null && context.mounted) {
                                          await context
                                              .read<EmoticonsDataEditorCubit>()
                                              .addNewTags(tags: tags);
                                          if (context.mounted) {
                                            if (context.mounted) {
                                              await context
                                                  .read<EmoticonsListingCubit>()
                                                  .loadEmoticons();
                                            }
                                          }
                                          if (context.mounted) {
                                            showSnackBar(
                                              context,
                                              text: "Added ${tags.length} tags",
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    PopupMenuItem(
                                      enabled: false,
                                      height: 10,
                                      child: PopupMenuDivider(),
                                    ),
                                    PopupMenuItem(
                                      child: ListTile(
                                        leading: BlankIconSpace(),
                                        title: const Text("Edit Tag Link"),
                                      ),
                                      onTap: () async {
                                        await context
                                            .read<EmoticonsDataEditorCubit>()
                                            .startModifyingLinks(
                                              allEmoticons: allEmoticons,
                                              allTags: allTags,
                                            );
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: ListTile(
                                        leading: Icon(Icons.delete),
                                        title: const Text("Delete"),
                                      ),
                                      onTap: () async {
                                        await context
                                            .read<EmoticonsDataEditorCubit>()
                                            .startDeleting(
                                              allEmoticons: allEmoticons,
                                              allTags: allTags,
                                            );
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: ListTile(
                                        leading: BlankIconSpace(),
                                        title: const Text("Reorder"),
                                      ),
                                      onTap: () async {
                                        await context
                                            .read<EmoticonsDataEditorCubit>()
                                            .startReordering(
                                              allEmoticons: allEmoticons,
                                              allTags: allTags,
                                            );
                                      },
                                    ),
                                  ];
                                default:
                                  return [];
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  body:
                      BlocBuilder<EmoticonsListingCubit, EmoticonsListingState>(
                    builder: (context, state) {
                      switch (state) {
                        case EmoticonsListingInitial():
                        case EmoticonsListingLoading():
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        case EmoticonsListingLoaded(
                            :final emoticonsToShow,
                            :final allTags
                          ):
                          return BlocBuilder<EmoticonsDataEditorCubit,
                              EmoticonsDataEditorState>(
                            builder: (context, state) {
                              switch (state) {
                                case EmoticonsDataEditorInitial():
                                case EmoticonsDataEditorLoading():
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                case EmoticonsDataEditorNotEditing():
                                  return EmoticonListingWrapped(
                                    allTags: allTags,
                                    controller: controller,
                                    emoticonsToShow: emoticonsToShow,
                                    settings: settings,
                                  );
                                case EmoticonsDataEditorEditing():
                                  return EmoticonsEditingView(
                                    state: state,
                                  );
                              }
                            },
                          );
                      }
                    },
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}

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

class EmoticonListingWrapped extends StatelessWidget {
  const EmoticonListingWrapped({
    super.key,
    required this.allTags,
    required this.controller,
    required this.emoticonsToShow,
    required this.settings,
  });

  final List<String> allTags;
  final TextEditingController controller;
  final List<Emoticon> emoticonsToShow;
  final GlobalSettings settings;

  @override
  Widget build(BuildContext context) {
    final emoticonListingViewId = "SingleChildScrollViewForEmoticons";
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GenericSearchBar(
            allTags: allTags,
            controller: controller,
            hintText: "Search by tag",
            onChange: (String text) {
              context.read<EmoticonsListingCubit>().searchEmoticons(
                    searchTerm: text,
                  );
            },
          ),
          const SizedBox(
            height: 20,
          ),
          Expanded(
            child: SingleChildScrollView(
              key: PageStorageKey(emoticonListingViewId),
              restorationId: emoticonListingViewId,
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 4.0,
                    runSpacing: 4.0,
                    children: emoticonsToShow.map(
                      (emoticon) {
                        return CopyableEmoticon(
                          emoticon: emoticon,
                          textSize: settings.emoticonsTextSize,
                          onLongPressed: (emoticon) async {
                            final result =
                                await showModalBottomSheet<BottomSheetResult?>(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) {
                                return UpdateEmoticonBottomSheet(
                                  newOrModifyEmoticon:
                                      NewOrModifyEmoticon.editExistingEmoticon(
                                    emoticon,
                                  ),
                                  isEditMode: true,
                                  allTags: allTags,
                                );
                              },
                            );
                            if (context.mounted) {
                              switch (result) {
                                case DeleteEmoticon(
                                      newOrModifyEmoticon: NewOrModifyEmoticon(
                                        :final oldEmoticon
                                      )
                                    )
                                    when oldEmoticon != null:
                                  await context
                                      .read<EmoticonsDataEditorCubit>()
                                      .deleteEmoticonsAndTags(
                                    emoticons: [oldEmoticon],
                                    tags: [],
                                  );
                                  if (context.mounted) {
                                    await context
                                        .read<EmoticonsListingCubit>()
                                        .loadEmoticons();
                                  }
                                case UpdateEmoticon(:final newOrModifyEmoticon):
                                  await context
                                      .read<EmoticonsDataEditorCubit>()
                                      .addNewEmoticons(
                                    newEmoticons: [newOrModifyEmoticon],
                                  );

                                  if (context.mounted) {
                                    await context
                                        .read<EmoticonsListingCubit>()
                                        .loadEmoticons();
                                  }
                                case TagClicked(:final tag):
                                  controller.text = tag;
                                case AddEmoticon():
                                case DeleteEmoticon():
                                case null:
                                  break;
                              }
                            }
                          },
                        );
                      },
                    ).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
