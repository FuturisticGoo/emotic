import 'package:emotic/core/image_cache_interface.dart';
import 'package:emotic/core/image_data.dart';
import 'package:emotic/cubit/emotipics_cubit.dart';
import 'package:emotic/cubit/emotipics_data_editor_cubit.dart';
import 'package:emotic/widgets/copyable_image.dart';
import 'package:emotic/widgets/emotipic_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ImageGridView extends StatefulWidget {
  final void Function(String tag) onTagClick;
  final ImageCacheInterface imageCacheInterface;
  final EmotipicsListingLoaded state;
  const ImageGridView({
    super.key,
    required this.onTagClick,
    required this.imageCacheInterface,
    required this.state,
  });

  @override
  State<ImageGridView> createState() => _ImageGridViewState();
}

class _ImageGridViewState extends State<ImageGridView> {
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
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: getCrossAxisCount(context),
        ),
        itemCount: widget.state.images.length,
        restorationId: "imagesListThing",
        itemBuilder: (context, index) {
          final currentImage = widget.state.images[index];
          final imageRepr =
              widget.state.visibleImageData[currentImage.imageUri];
          if (imageRepr case FlutterImageWidgetImageRepr(:final imageWidget)) {
            widget.imageCacheInterface
                .setCacheImage(currentImage.imageUri, imageWidget);
          }
          final currentCachedImage =
              widget.imageCacheInterface.getCachedImage(currentImage.imageUri);
          return VisibilityDetector(
            key: Key(widget.state.images[index].toString()),
            child: currentCachedImage != null
                ? CopyableImage(
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
                      final result = await showModalBottomSheet<
                          EmotipicBottomSheetResult?>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) {
                          return UpdateEmotipicBottomSheet(
                            image: currentCachedImage,
                            emoticImage: emoticImage,
                            allTags: widget.state.allTags,
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
                                    emoticImages: [emoticImage]);
                          case UpdateEmotipic(:final modifyEmotipic):
                            await context
                                .read<EmotipicsDataEditorCubit>()
                                .modifyImage(
                                  newOrModifyEmoticImage: modifyEmotipic,
                                );
                          case EmotipicTagClicked(:final tag):
                            widget.onTagClick(tag);
                        }
                      }
                    },
                  )
                : Center(
                    child: SizedBox.square(
                      dimension: MediaQuery.sizeOf(context).shortestSide * 0.05,
                      child: CircularProgressIndicator(),
                    ),
                  ),
            onVisibilityChanged: (info) async {
              if (info.visibleFraction > 0) {
                if (!widget.imageCacheInterface
                    .isImageCached(widget.state.images[index].imageUri)) {
                  await context.read<EmotipicsListingCubit>().loadImageBytes(
                        imageToLoad: widget.state.images[index].imageUri,
                      );
                }
              } else {
                if (context.mounted) {
                  await context.read<EmotipicsListingCubit>().unloadImageBytes(
                        imageToUnload: widget.state.images[index].imageUri,
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
