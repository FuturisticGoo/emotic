import 'package:emotic/core/entities/image_cache_interface.dart';
import 'package:emotic/core/entities/image_data.dart';
import 'package:emotic/cubit/emotipics_cubit.dart';
import 'package:emotic/cubit/emotipics_data_editor_cubit.dart';
import 'package:emotic/pages/emotipics_page_widgets/copyable_image.dart';
import 'package:emotic/pages/emotipics_page_widgets/emotipic_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart' as fp;
import 'package:visibility_detector/visibility_detector.dart';

class ImageGridView extends StatefulWidget {
  final void Function(String tag) onTagClick;
  final int? emotipicsColCount;

  final ImageCacheInterface imageCacheInterface;
  final EmotipicsListingLoaded state;

  const ImageGridView({
    super.key,
    required this.onTagClick,
    required this.imageCacheInterface,
    required this.state,
    required this.emotipicsColCount,
  });

  @override
  State<ImageGridView> createState() => _ImageGridViewState();
}

class _ImageGridViewState extends State<ImageGridView> {
  final emotipicsListingsKey = "emotipicListingKey";

  int getCrossAxisCount(BuildContext context) {
    final dPR = MediaQuery.devicePixelRatioOf(context);

    final size = MediaQuery.sizeOf(context);
    // An image should have width of 240 pixels in a 1 dpr screen
    // So that means, 3 horizontal images in a 720 width screen
    // The below equation gets the number of horizontal images that should fit
    // neatly in a screen with width=size.width
    final crossAxisCount = (dPR * size.width) / 240;
    return crossAxisCount.ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: widget.state.imagesToShow.isEmpty
          ? Center(
              child: Text("Nothing but the void O.o"),
            )
          : GridView.builder(
              key: PageStorageKey(emotipicsListingsKey),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    widget.emotipicsColCount ?? getCrossAxisCount(context),
              ),
              itemCount: widget.state.imagesToShow.length,
              itemBuilder: (context, index) {
                final currentImage = widget.state.imagesToShow[index];
                final imageReprResult =
                    widget.state.visibleImageData[currentImage.imageUri];
                switch (imageReprResult) {
                  case fp.Right(
                      value: FlutterImageWidgetImageRepr(:final imageWidget)
                    ):
                    widget.imageCacheInterface
                        .setCacheImage(currentImage.imageUri, imageWidget);
                  default:
                    break;
                }
                final currentCachedImage = widget.imageCacheInterface
                    .getCachedImage(currentImage.imageUri);
                return VisibilityDetector(
                  key: Key(
                      "visibility-${widget.state.imagesToShow[index].imageUri}"),
                  child: switch (imageReprResult) {
                    fp.Left(:final value) => Placeholder(
                        child: Center(
                          child: Text(
                            value.message,
                          ),
                        ),
                      ),
                    _ => switch (currentCachedImage) {
                        null => Center(
                            child: SizedBox.square(
                              dimension:
                                  MediaQuery.sizeOf(context).shortestSide *
                                      0.05,
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        _ => CopyableImage(
                            imageWidget: currentCachedImage,
                            emoticImage: currentImage,
                            onTap: (emoticImage) async {
                              await context
                                  .read<EmotipicsListingCubit>()
                                  .copyImageToClipboard(
                                    emoticImage: emoticImage,
                                  );
                            },
                            onSecondaryPress: (emoticImage) async {
                              final emotipicsCubit =
                                  context.read<EmotipicsListingCubit>();
                              final result = await showModalBottomSheet<
                                  EmotipicBottomSheetResult?>(
                                context: context,
                                isScrollControlled: true,
                                builder: (bottomSheetContext) {
                                  return BlocProvider.value(
                                    value: emotipicsCubit,
                                    child: UpdateEmotipicBottomSheet(
                                      emoticImage: emoticImage,
                                      allTags: widget.state.allTags,
                                      loadImageBytes: (
                                        Uri imageToLoad,
                                        ImageReprConfig? imageReprConfig,
                                      ) async {
                                        await emotipicsCubit.loadImageBytes(
                                          imageToLoad: imageToLoad,
                                          imageReprConfig: imageReprConfig,
                                        );
                                      },
                                      unloadImageBytes: (
                                        Uri imageToUnload,
                                      ) async {
                                        await emotipicsCubit.unloadImageBytes(
                                          imageToUnload: imageToUnload,
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                              if (context.mounted) {
                                switch (result) {
                                  case null:
                                    break;
                                  case DeleteEmotipic(:final emoticImage):
                                    await context
                                        .read<EmotipicsDataEditorCubit>()
                                        .deleteImagesAndTags(
                                      emoticImages: [emoticImage],
                                      tags: [],
                                    );
                                    if (context.mounted) {
                                      await context
                                          .read<EmotipicsListingCubit>()
                                          .loadSavedImages();
                                    }
                                  case UpdateEmotipic(:final modifyEmotipic):
                                    await context
                                        .read<EmotipicsDataEditorCubit>()
                                        .modifyImage(
                                          newOrModifyEmoticImage:
                                              modifyEmotipic,
                                        );
                                    if (context.mounted) {
                                      await context
                                          .read<EmotipicsListingCubit>()
                                          .loadSavedImages();
                                    }
                                  case ShareEmotipic(:final selectedImage):
                                    if (context.mounted) {
                                      await context
                                          .read<EmotipicsListingCubit>()
                                          .shareImage(image: selectedImage);
                                    }
                                  case EmotipicTagClicked(:final tag):
                                    widget.onTagClick(tag);
                                }
                              }
                            },
                          )
                      }
                  },
                  onVisibilityChanged: (info) async {
                    if (info.visibleFraction > 0) {
                      if (!widget.imageCacheInterface.isImageCached(
                          widget.state.imagesToShow[index].imageUri)) {
                        await context
                            .read<EmotipicsListingCubit>()
                            .loadImageBytes(
                              imageToLoad:
                                  widget.state.imagesToShow[index].imageUri,
                            );
                      }
                    } else {
                      // TODO: investigate why this index condition is required
                      // for preventing list out of bound index error
                      if (context.mounted &&
                          (index < widget.state.imagesToShow.length)) {
                        await context
                            .read<EmotipicsListingCubit>()
                            .unloadImageBytes(
                              imageToUnload:
                                  widget.state.imagesToShow[index].imageUri,
                            );
                      }
                    }
                  },
                );
              },
            ),
    );
  }
}
