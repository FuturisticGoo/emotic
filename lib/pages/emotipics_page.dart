import 'package:emotic/core/image_cache_interface.dart';
import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/routes.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/emotipics_cubit.dart';
import 'package:emotic/cubit/emotipics_data_editor_cubit.dart';
import 'package:emotic/pages/emotipics_page_widgets/emotipics_app_bar.dart';
import 'package:emotic/pages/emotipics_page_widgets/image_editing_list_view.dart';
import 'package:emotic/pages/emotipics_page_widgets/image_grid_view.dart';
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
                child: BlocListener<EmotipicsDataEditorCubit,
                    EmotipicsDataEditorState>(
                  listener: (context, state) {
                    switch (state) {
                      case EmotipicsDataEditorEditing(:final snackBarMessage)
                          when snackBarMessage != null:
                      case EmotipicsDataEditorNotEditing(:final snackBarMessage)
                          when snackBarMessage != null:
                        showSnackBar(context, text: snackBarMessage);
                      default:
                        break;
                    }
                  },
                  child: SafeArea(
                    child: Scaffold(
                      appBar: EmotipicsAppBar(),
                      body: BlocBuilder<EmotipicsListingCubit,
                          EmotipicsListingState>(
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
                                  return previous
                                          is EmotipicsDataEditorEditing &&
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
                                              hintText:
                                                  "Search by tag and note",
                                              onChange: (searchText) async {
                                                if (context.mounted) {
                                                  await context
                                                      .read<
                                                          EmotipicsListingCubit>()
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
                                                setCacheImage:
                                                    (imageUri, image) {
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
                                      );
                                  }
                                },
                              );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}
