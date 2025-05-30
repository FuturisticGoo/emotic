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
import 'package:emotic/widgets_common/blank_icon_space.dart';
import 'package:emotic/widgets_common/delete_confirmation.dart';
import 'package:emotic/pages/emoticons_page_widgets/emoticons_editing_view.dart';
import 'package:emotic/pages/emoticons_page_widgets/emoticons_listing_wrapped.dart';
import 'package:emotic/widgets_common/read_list_of_string_from_user.dart';
import 'package:emotic/widgets_common/show_message.dart';
import 'package:emotic/pages/emoticons_page_widgets/update_emoticon_bottom_sheet.dart';
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
                                  return EmoticonsListingWrapped(
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
