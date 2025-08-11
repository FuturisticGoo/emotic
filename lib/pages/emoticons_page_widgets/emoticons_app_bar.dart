import 'package:emotic/core/entities/emoticon.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/emoticons_data_editor_cubit.dart';
import 'package:emotic/cubit/emoticons_data_editor_state.dart';
import 'package:emotic/cubit/emoticons_listing_cubit.dart';
import 'package:emotic/cubit/emoticons_listing_state.dart';
import 'package:emotic/pages/emoticons_page_widgets/update_emoticon_bottom_sheet.dart';
import 'package:emotic/widgets_common/blank_icon_space.dart';
import 'package:emotic/widgets_common/delete_confirmation.dart';
import 'package:emotic/widgets_common/read_list_of_string_from_user.dart';
import 'package:emotic/widgets_common/show_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmoticonsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EmoticonsAppBar({
    super.key,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text("Emoticons"),
      leading: DrawerButton(
        onPressed: context.openRootScaffoldDrawer,
      ),
      actions: [
        BlocBuilder<EmoticonsDataEditorCubit, EmoticonsDataEditorState>(
          builder: (context, state) {
            if (state case EmoticonsDataEditorEditing()) {
              return IconButton(
                onPressed: () async {
                  context.read<EmoticonsDataEditorCubit>().finishEditing();
                },
                icon: Icon(Icons.check),
              );
            } else {
              return SizedBox.shrink();
            }
          },
        ),
        BlocBuilder<EmoticonsDataEditorCubit, EmoticonsDataEditorState>(
          builder: (context, state) {
            if (state
                case EmoticonsDataEditorDeleteData(
                  :final selectedEmoticons,
                  :final selectedTags
                )) {
              return IconButton(
                onPressed: () async {
                  final choice = await confirmDeletionDialog(context,
                      titleText: "Delete ${selectedEmoticons.length}"
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
                              case EmoticonsListingLoaded(:final allTags)) {
                            final result =
                                await showModalBottomSheet<BottomSheetResult?>(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) {
                                return UpdateEmoticonBottomSheet(
                                  allTags: allTags,
                                  isEditMode: false,
                                  newOrModifyEmoticon:
                                      NewOrModifyEmoticon.newEmoticon(),
                                );
                              },
                            );
                            switch (result) {
                              case AddEmoticon(:final newOrModifyEmoticon):
                                if (context.mounted) {
                                  await context
                                      .read<EmoticonsDataEditorCubit>()
                                      .addNewEmoticons(
                                    newEmoticons: [newOrModifyEmoticon],
                                  );
                                }
                                if (context.mounted) {
                                  await context
                                      .read<EmoticonsListingCubit>()
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

                          if (emoticonsStringList != null && context.mounted) {
                            await context
                                .read<EmoticonsDataEditorCubit>()
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
                            if (context.mounted) {
                              await context
                                  .read<EmoticonsListingCubit>()
                                  .loadEmoticons();
                            }
                            if (context.mounted) {
                              showSnackBar(
                                context,
                                text: "Added ${emoticonsStringList.length}"
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
                        child: BlocBuilder<GlobalSettingsCubit,
                            GlobalSettingsState>(
                          builder: (context, state) {
                            final int fontSize;
                            switch (state) {
                              case GlobalSettingsLoaded(:final settings):
                                fontSize = settings.emoticonsTextSize ?? 12;
                              default:
                                fontSize = 12;
                            }
                            return ListTile(
                              leading: BlankIconSpace(),
                              // title: const Text("Zoom"),
                              title: IntrinsicWidth(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text("Zoom"),
                                    const Spacer(),
                                    ActionChip(
                                      onPressed: () async {
                                        final newfontSize = fontSize - 1;
                                        await context
                                            .read<GlobalSettingsCubit>()
                                            .changeEmoticonsFontSize(
                                              newSize: newfontSize,
                                            );
                                      },
                                      labelPadding: EdgeInsets.fromLTRB(
                                        2,
                                        0,
                                        2,
                                        0,
                                      ),
                                      padding: EdgeInsets.all(0),
                                      label: Icon(Icons.remove),
                                    ),
                                    const SizedBox(width: 4),
                                    Text("$fontSize"),
                                    const SizedBox(width: 4),
                                    ActionChip(
                                      onPressed: () async {
                                        final newfontSize = fontSize + 1;
                                        await context
                                            .read<GlobalSettingsCubit>()
                                            .changeEmoticonsFontSize(
                                              newSize: newfontSize,
                                            );
                                      },
                                      labelPadding: EdgeInsets.fromLTRB(
                                        2,
                                        0,
                                        2,
                                        0,
                                      ),
                                      padding: EdgeInsets.all(0),
                                      label: Icon(Icons.add),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
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
    );
  }
}
