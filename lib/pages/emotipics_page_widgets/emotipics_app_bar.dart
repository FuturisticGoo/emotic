import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/emotipics_cubit.dart';
import 'package:emotic/cubit/emotipics_data_editor_cubit.dart';
import 'package:emotic/widgets_common/blank_icon_space.dart';
import 'package:emotic/widgets_common/delete_confirmation.dart';
import 'package:emotic/widgets_common/read_list_of_string_from_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmotipicsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EmotipicsAppBar({
    super.key,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text("Emotipics"),
      leading: DrawerButton(
        onPressed: context.openRootScaffoldDrawer,
      ),
      actions: [
        BlocBuilder<EmotipicsDataEditorCubit, EmotipicsDataEditorState>(
          builder: (context, state) {
            if (state case EmotipicsDataEditorEditing()) {
              return IconButton(
                onPressed: () async {
                  context.read<EmotipicsDataEditorCubit>().finishEditing();
                },
                icon: Icon(Icons.check),
              );
            } else {
              return SizedBox.shrink();
            }
          },
        ),
        BlocBuilder<EmotipicsDataEditorCubit, EmotipicsDataEditorState>(
          builder: (context, state) {
            if (state
                case EmotipicsDataEditorDelete(
                  :final selectedImages,
                  :final selectedTags
                )) {
              return IconButton(
                onPressed: () async {
                  final choice = await confirmDeletionDialog(context,
                      titleText: "Delete ${selectedImages.length} images"
                          " and ${selectedTags.length} tags?");
                  if (choice == true && context.mounted) {
                    await context
                        .read<EmotipicsDataEditorCubit>()
                        .deleteImagesAndTags(
                          emoticImages: selectedImages,
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
        BlocBuilder<EmotipicsListingCubit, EmotipicsListingState>(
          builder: (context, emotipicsListingState) {
            return PopupMenuButton(
              itemBuilder: (context) {
                switch (emotipicsListingState) {
                  case EmotipicsListingLoaded(:final images, :final allTags):
                    return [
                      PopupMenuItem(
                        child: ListTile(
                          leading: Icon(
                            Icons.refresh,
                          ),
                          title: Text("Refresh"),
                        ),
                        onTap: () async {
                          await context
                              .read<EmotipicsDataEditorCubit>()
                              .refreshImages();
                          if (context.mounted) {
                            await context
                                .read<EmotipicsListingCubit>()
                                .loadSavedImages();
                          }
                        },
                      ),
                      PopupMenuItem(
                        child: ListTile(
                          leading: Icon(
                            Icons.add_photo_alternate,
                          ),
                          title: Text("Add Image(s)"),
                        ),
                        onTap: () async {
                          await context
                              .read<EmotipicsDataEditorCubit>()
                              .pickImages();
                          if (context.mounted) {
                            await context
                                .read<EmotipicsListingCubit>()
                                .loadSavedImages();
                          }
                        },
                      ),
                      PopupMenuItem(
                        child: ListTile(
                          leading: Icon(
                            Icons.create_new_folder,
                          ),
                          title: Text("Add Folder"),
                        ),
                        onTap: () async {
                          await context
                              .read<EmotipicsDataEditorCubit>()
                              .pickDirectory();
                          if (context.mounted) {
                            await context
                                .read<EmotipicsListingCubit>()
                                .loadSavedImages();
                          }
                        },
                      ),
                      PopupMenuItem(
                        child: ListTile(
                          leading: BlankIconSpace(),
                          title: Text("Add Tag(s)"),
                        ),
                        onTap: () async {
                          final newTags = await readTags(context);
                          if (newTags != null && context.mounted) {
                            await context
                                .read<EmotipicsDataEditorCubit>()
                                .addTags(
                                  tags: newTags,
                                );
                            if (context.mounted) {
                              await context
                                  .read<EmotipicsListingCubit>()
                                  .loadSavedImages();
                            }
                          }
                        },
                      ),
                      PopupMenuItem(
                        child: BlocBuilder<GlobalSettingsCubit,
                            GlobalSettingsState>(
                          builder: (context, state) {
                            final int colCount;
                            switch (state) {
                              case GlobalSettingsLoaded(:final settings):
                                colCount = settings.emotipicsColumnCount ?? 3;
                              default:
                                colCount = 3;
                            }
                            return ListTile(
                              leading: BlankIconSpace(),
                              title: IntrinsicWidth(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text("Zoom"),
                                    const Spacer(),
                                    ActionChip(
                                      onPressed: () async {
                                        final newColCount = colCount + 1;
                                        await context
                                            .read<GlobalSettingsCubit>()
                                            .changeEmotipicsColCount(
                                              colCount: newColCount,
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
                                    Text("$colCount"),
                                    const SizedBox(width: 4),
                                    ActionChip(
                                      onPressed: () async {
                                        final newColCount = colCount - 1;
                                        await context
                                            .read<GlobalSettingsCubit>()
                                            .changeEmotipicsColCount(
                                              colCount: newColCount,
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
                          title: Text("Edit Tag Link"),
                        ),
                        onTap: () async {
                          await context
                              .read<EmotipicsDataEditorCubit>()
                              .startModifyingTagLink(
                            images: images,
                            allTags: allTags,
                            visibleImageData: {},
                          );
                        },
                      ),
                      PopupMenuItem(
                        child: ListTile(
                          leading: Icon(Icons.delete),
                          title: Text("Delete"),
                        ),
                        onTap: () async {
                          await context
                              .read<EmotipicsDataEditorCubit>()
                              .startDeleting(
                            images: images,
                            allTags: allTags,
                            visibleImageData: {},
                          );
                        },
                      ),
                      PopupMenuItem(
                        child: ListTile(
                          leading: BlankIconSpace(),
                          title: Text("Reorder"),
                        ),
                        onTap: () async {
                          await context
                              .read<EmotipicsDataEditorCubit>()
                              .startModifyingOrder(
                            images: images,
                            allTags: allTags,
                            visibleImageData: {},
                          );
                        },
                      ),
                      PopupMenuItem(
                        child: ListTile(
                          leading: Icon(Icons.hide_image_outlined),
                          title: Text("Hide image(s)"),
                        ),
                        onTap: () async {
                          await context
                              .read<EmotipicsDataEditorCubit>()
                              .startHidingImages(
                            images: images,
                            allTags: allTags,
                            visibleImageData: {},
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
