import 'package:emotic/core/image_cache_interface.dart';
import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/core/routes.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/emotipics_cubit.dart';
import 'package:emotic/cubit/emotipics_data_editor_cubit.dart';
import 'package:emotic/widgets_common/blank_icon_space.dart';
import 'package:emotic/widgets_common/delete_confirmation.dart';
import 'package:emotic/pages/emotipics_page_widgets/image_editing_list_view.dart';
import 'package:emotic/pages/emotipics_page_widgets/image_grid_view.dart';
import 'package:emotic/widgets_common/read_list_of_string_from_user.dart';
import 'package:emotic/widgets_common/search_bar.dart';
import 'package:emotic/widgets_common/show_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class EmotipicsPage extends StatefulWidget {
  const EmotipicsPage({super.key});

  @override
  State<EmotipicsPage> createState() => _EmotipicsPageState();
}

class _EmotipicsPageState extends State<EmotipicsPage> {
  TextEditingController controller = TextEditingController();
  final Map<Uri, Image> cachedImage = {};
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
      builder: (context, settingsState) {
        switch (settingsState) {
          case GlobalSettingsInitial():
          case GlobalSettingsLoading():
            return Center(
              child: CircularProgressIndicator(),
            );
          case GlobalSettingsLoaded(:final settings):
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (context) => EmotipicsListingCubit(
                    imageRepository: sl(),
                  ),
                ),
                BlocProvider(
                  create: (context) => EmotipicsDataEditorCubit(
                    imageRepository: sl(),
                  ),
                )
              ],
              child: BlocListener<EmotipicsListingCubit, EmotipicsListingState>(
                listener: (context, state) async {
                  if (state case EmotipicsListingLoaded(:final snackBarMessage)
                      when snackBarMessage != null) {
                    showSnackBar(context, text: snackBarMessage);
                  }
                },
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text("Emotipics"),
                    leading: DrawerButton(
                      onPressed: context.openRootScaffoldDrawer,
                    ),
                    actions: [
                      BlocBuilder<EmotipicsDataEditorCubit,
                          EmotipicsDataEditorState>(
                        builder: (context, state) {
                          if (state case EmotipicsDataEditorEditing()) {
                            return IconButton(
                              onPressed: () async {
                                context
                                    .read<EmotipicsDataEditorCubit>()
                                    .finishEditing();
                              },
                              icon: Icon(Icons.check),
                            );
                          } else {
                            return SizedBox.shrink();
                          }
                        },
                      ),
                      BlocBuilder<EmotipicsDataEditorCubit,
                          EmotipicsDataEditorState>(
                        builder: (context, state) {
                          if (state
                              case EmotipicsDataEditorDelete(
                                :final selectedImages,
                                :final selectedTags
                              )) {
                            return IconButton(
                              onPressed: () async {
                                final choice = await confirmDeletionDialog(
                                    context,
                                    titleText:
                                        "Delete ${selectedImages.length} images"
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
                                case EmotipicsListingLoaded(
                                    :final images,
                                    :final allTags
                                  ):
                                  return [
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
                                        if (newTags != null &&
                                            context.mounted) {
                                          await context
                                              .read<EmotipicsDataEditorCubit>()
                                              .addTags(
                                                tags: newTags,
                                              );
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
                      BlocBuilder<EmotipicsListingCubit, EmotipicsListingState>(
                    builder: (context, listingState) {
                      switch (listingState) {
                        case EmotipicsListingInitial():
                        case EmotipicsListingLoading():
                          return Center(
                            child: CircularProgressIndicator(),
                          );
                        case EmotipicsListingError():
                          return Center(
                            child: Text("Error loading images"),
                          );
                        case EmotipicsListingLoaded(:final allTags):
                          return BlocConsumer<EmotipicsDataEditorCubit,
                              EmotipicsDataEditorState>(
                            listener: (context, state) async {
                              await context
                                  .read<EmotipicsListingCubit>()
                                  .loadSavedImages();
                            },
                            listenWhen: (previous, current) {
                              return previous is EmotipicsDataEditorEditing &&
                                  current is EmotipicsDataEditorNotEditing;
                            },
                            builder: (context, state) {
                              switch (state) {
                                case EmotipicsDataEditorInitial():
                                case EmotipicsDataEditorLoading():
                                case EmotipicsDataEditorNotEditing():
                                  return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      children: [
                                        GenericSearchBar(
                                          allTags: allTags,
                                          controller: controller,
                                          hintText: "Search by tag and note",
                                          onChange: (searchText) async {
                                            if (context.mounted) {
                                              await context
                                                  .read<EmotipicsListingCubit>()
                                                  .searchWithText(
                                                    searchText: searchText,
                                                  );
                                            }
                                          },
                                        ),
                                        SizedBox(
                                          height: 10,
                                        ),
                                        ImageGridView(
                                          state: listingState,
                                          emotipicsColCount:
                                              settings.emotipicsColumnCount,
                                          onTagClick: (tag) {
                                            controller.text = tag;
                                          },
                                          imageCacheInterface:
                                              ImageCacheInterface(
                                            getCachedImage: (imageUri) {
                                              return cachedImage[imageUri];
                                            },
                                            setCacheImage: (imageUri, image) {
                                              cachedImage[imageUri] = image;
                                            },
                                            isImageCached: (imageUri) {
                                              return cachedImage
                                                  .containsKey(imageUri);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                case EmotipicsDataEditorEditing():
                                  return ImageEditingListView(
                                    editorState: state,
                                    imageCacheInterface: ImageCacheInterface(
                                      getCachedImage: (imageUri) {
                                        return cachedImage[imageUri];
                                      },
                                      setCacheImage: (imageUri, image) {
                                        cachedImage[imageUri] = image;
                                      },
                                      isImageCached: (imageUri) {
                                        return cachedImage
                                            .containsKey(imageUri);
                                      },
                                    ),
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
