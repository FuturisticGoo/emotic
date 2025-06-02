import 'package:emotic/core/image_cache_interface.dart';
import 'package:emotic/core/image_data.dart';
import 'package:emotic/cubit/emotipics_data_editor_cubit.dart';
import 'package:emotic/pages/emotipics_page_widgets/emotipic_tile.dart';
import 'package:emotic/widgets_common/tag_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart' as fp;
import 'package:visibility_detector/visibility_detector.dart';

class ImageEditingListView extends StatefulWidget {
  final EmotipicsDataEditorEditing editorState;
  final ImageCacheInterface imageCacheInterface;
  const ImageEditingListView({
    super.key,
    required this.editorState,
    required this.imageCacheInterface,
  });

  @override
  State<ImageEditingListView> createState() => _ImageEditingListViewState();
}

class _ImageEditingListViewState extends State<ImageEditingListView> {
  final String emotipicsListKey = "emotipicsListKey";
  final String tagsListKey = "emotipicsTagsListKey";
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
                switch (widget.editorState) {
                  EmotipicsDataEditorModifyTagLink() =>
                    "Select an image to modify its tags",
                  EmotipicsDataEditorDelete() =>
                    "Select the images and tags you wish to delete",
                  EmotipicsDataEditorModifyOrder() =>
                    "Drag the handle to reorder images or tags",
                  EmotipicsDataEditorHiding() =>
                    "Select the images you wish to hide",
                },
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: widget.editorState is EmotipicsDataEditorModifyOrder
                      ? ReorderableListView.builder(
                          key: PageStorageKey(emotipicsListKey),
                          buildDefaultDragHandles: false,
                          onReorder: (oldIndex, newIndex) async {
                            if (oldIndex < newIndex) {
                              // removing the item at oldIndex will shorten the list by 1.
                              newIndex -= 1;
                            }
                            await context
                                .read<EmotipicsDataEditorCubit>()
                                .reorderEmotipic(
                                  oldIndex: oldIndex,
                                  newIndex: newIndex,
                                );
                          },
                          itemCount: widget.editorState.images.length,
                          itemBuilder: (context, index) {
                            final currentImage =
                                widget.editorState.images[index];

                            final imageReprResult = widget.editorState
                                .visibleImageData[currentImage.imageUri];
                            switch (imageReprResult) {
                              case fp.Right(
                                  value: FlutterImageWidgetImageRepr(
                                    :final imageWidget
                                  )
                                ):
                                widget.imageCacheInterface.setCacheImage(
                                    currentImage.imageUri, imageWidget);
                              default:
                                break;
                            }
                            final currentCachedImage = widget
                                .imageCacheInterface
                                .getCachedImage(currentImage.imageUri);

                            return VisibilityDetector(
                              key: Key("visibility-${currentImage.imageUri}"),
                              child: EmotipicTile(
                                key: Key("emotipic-${currentImage.id}"),
                                image: currentImage,
                                imageWidget: switch (imageReprResult) {
                                  fp.Left(:final value) => Placeholder(
                                      child: Center(
                                        child: Text(
                                          value.message,
                                        ),
                                      ),
                                    ),
                                  _ => currentCachedImage,
                                },
                                isSelected: false,
                                onTap: () {},
                                trailing: ReorderableDragStartListener(
                                  key: ValueKey(
                                    index,
                                  ),
                                  index: index,
                                  child: const Icon(
                                    Icons.drag_handle,
                                  ),
                                ),
                              ),
                              onVisibilityChanged: (info) async {
                                if (info.visibleFraction > 0) {
                                  if (!widget.imageCacheInterface
                                      .isImageCached(currentImage.imageUri)) {
                                    await context
                                        .read<EmotipicsDataEditorCubit>()
                                        .loadImageBytes(
                                          imageToLoad: currentImage.imageUri,
                                        );
                                  }
                                } else {
                                  if (context.mounted) {
                                    await context
                                        .read<EmotipicsDataEditorCubit>()
                                        .unloadImageBytes(
                                          imageToUnload: currentImage.imageUri,
                                        );
                                  }
                                }
                              },
                            );
                          },
                        )
                      : ListView.builder(
                          key: PageStorageKey(emotipicsListKey),
                          itemCount: widget.editorState.images.length,
                          itemBuilder: (context, index) {
                            final currentImage =
                                widget.editorState.images[index];
                            final imageReprResult = widget.editorState
                                .visibleImageData[currentImage.imageUri];
                            switch (imageReprResult) {
                              case fp.Right(
                                  value: FlutterImageWidgetImageRepr(
                                    :final imageWidget
                                  )
                                ):
                                widget.imageCacheInterface.setCacheImage(
                                    currentImage.imageUri, imageWidget);
                              default:
                                break;
                            }
                            final currentCachedImage = widget
                                .imageCacheInterface
                                .getCachedImage(currentImage.imageUri);

                            final isSelected = switch (widget.editorState) {
                              EmotipicsDataEditorModifyTagLink(
                                :final selectedImage
                              ) =>
                                selectedImage?.id == currentImage.id,
                              EmotipicsDataEditorDelete(
                                :final selectedImages
                              ) =>
                                selectedImages.contains(currentImage),
                              EmotipicsDataEditorHiding(
                                :final selectedImages
                              ) =>
                                selectedImages.contains(currentImage),
                              _ => false,
                            };
                            return VisibilityDetector(
                              key: Key("visibility-${currentImage.imageUri}"),
                              child: EmotipicTile(
                                key: Key("emotipic-${currentImage.id}"),
                                image: currentImage,
                                imageWidget: switch (imageReprResult) {
                                  fp.Left(:final value) => Placeholder(
                                      child: Center(
                                        child: Text(
                                          value.message,
                                        ),
                                      ),
                                    ),
                                  _ => currentCachedImage,
                                },
                                isSelected: isSelected,
                                onTap: () async {
                                  await context
                                      .read<EmotipicsDataEditorCubit>()
                                      .selectEmotipic(
                                        image: currentImage,
                                      );
                                },
                                trailing: null,
                              ),
                              onVisibilityChanged: (info) async {
                                if (info.visibleFraction > 0) {
                                  if (!widget.imageCacheInterface
                                      .isImageCached(currentImage.imageUri)) {
                                    await context
                                        .read<EmotipicsDataEditorCubit>()
                                        .loadImageBytes(
                                          imageToLoad: currentImage.imageUri,
                                        );
                                  }
                                } else {
                                  if (context.mounted) {
                                    await context
                                        .read<EmotipicsDataEditorCubit>()
                                        .unloadImageBytes(
                                          imageToUnload: currentImage.imageUri,
                                        );
                                  }
                                }
                              },
                            );
                          },
                        ),
                ),
                Expanded(
                  child: widget.editorState is EmotipicsDataEditorModifyOrder
                      ? ReorderableListView.builder(
                          key: PageStorageKey(tagsListKey),
                          buildDefaultDragHandles: false,
                          onReorder: (oldIndex, newIndex) async {
                            if (oldIndex < newIndex) {
                              // removing the item at oldIndex will shorten the list by 1.
                              newIndex -= 1;
                            }
                            await context
                                .read<EmotipicsDataEditorCubit>()
                                .reorderTag(
                                  oldIndex: oldIndex,
                                  newIndex: newIndex,
                                );
                          },
                          itemCount: widget.editorState.allTags.length,
                          itemBuilder: (context, index) {
                            final currentTag =
                                widget.editorState.allTags[index];
                            return TagTile(
                              key: Key("tag-$currentTag"),
                              tag: currentTag,
                              isSelected: false,
                              onTap: () {},
                              trailing: ReorderableDragStartListener(
                                key: ValueKey(
                                  index,
                                ),
                                index: index,
                                child: const Icon(
                                  Icons.drag_handle,
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          key: PageStorageKey(tagsListKey),
                          itemCount: widget.editorState.allTags.length,
                          itemBuilder: (context, index) {
                            final currentTag =
                                widget.editorState.allTags[index];

                            final isSelected = switch (widget.editorState) {
                              EmotipicsDataEditorModifyTagLink(
                                :final selectedImage
                              ) =>
                                selectedImage?.tags.contains(currentTag) ??
                                    false,
                              EmotipicsDataEditorDelete(:final selectedTags) =>
                                selectedTags.contains(currentTag),
                              _ => false,
                            };
                            return TagTile(
                              key: Key("tag-$currentTag"),
                              tag: currentTag,
                              isSelected: isSelected,
                              onTap: () async {
                                await context
                                    .read<EmotipicsDataEditorCubit>()
                                    .selectTag(tag: currentTag);
                              },
                              trailing: null,
                            );
                          },
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
