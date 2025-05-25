import 'package:emotic/core/image_data.dart';
import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/cubit/emotipics_cubit.dart';
import 'package:emotic/widgets/copyable_image.dart';
import 'package:emotic/widgets/search_bar.dart';
import 'package:emotic/widgets/show_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:visibility_detector/visibility_detector.dart';

class EmotiPicsPage extends StatefulWidget {
  const EmotiPicsPage({super.key});

  @override
  State<EmotiPicsPage> createState() => _EmotiPicsPageState();
}

class _EmotiPicsPageState extends State<EmotiPicsPage> {
  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EmotipicsListingCubit(
        imageRepository: sl(),
      ),
      child: BlocListener<EmotipicsListingCubit, EmotipicsListingState>(
        listener: (context, state) async {
          switch (state) {
            case EmotipicsListingLoaded(:final snackBarMessage)
                when snackBarMessage != null:
              showSnackBar(context, text: snackBarMessage);
            default:
              break;
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text("EmotiPics"),
            leading: DrawerButton(
              onPressed: context.openRootScaffoldDrawer,
            ),
            actions: [
              PopupMenuButton(
                itemBuilder: (context) {
                  return [
                    PopupMenuItem(
                      child: Text("Add image(s)"),
                      onTap: () async {
                        await context
                            .read<EmotipicsListingCubit>()
                            .pickImages();
                      },
                    ),
                    PopupMenuItem(
                      child: Text("Add folder"),
                      onTap: () async {
                        await context
                            .read<EmotipicsListingCubit>()
                            .pickDirectory();
                      },
                    ),
                  ];
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                GenericSearchBar(
                  allTags: [],
                  controller: controller,
                  hintText: "Search by tag and note",
                  onChange: (p0) {},
                ),
                SizedBox(
                  height: 10,
                ),
                ImageGridView(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ImageGridView extends StatefulWidget {
  const ImageGridView({
    super.key,
  });

  @override
  State<ImageGridView> createState() => _ImageGridViewState();
}

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

class _ImageGridViewState extends State<ImageGridView> {
  final Map<Uri, Image> cachedImage = {};
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmotipicsListingCubit, EmotipicsListingState>(
      builder: (context, state) {
        switch (state) {
          case EmotipicsListingInitial():
          case EmotipicsListingLoading():
            return Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          case EmotipicsListingError():
            return Center(
              child: Text("Error loading images"),
            );
          case EmotipicsListingLoaded(:final images, :final visibleImageData):
            return Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: getCrossAxisCount(context),
                ),
                itemCount: images.length,
                restorationId: "imagesListThing",
                itemBuilder: (context, index) {
                  final currentImage = images[index];
                  final imageRepr = visibleImageData[currentImage.imageUri];
                  if (imageRepr
                      case FlutterImageWidgetImageRepr(:final imageWidget)) {
                    cachedImage[currentImage.imageUri] = imageWidget;
                  }
                  final currentCachedImage = cachedImage[currentImage.imageUri];
                  return VisibilityDetector(
                    key: Key(images[index].toString()),
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
                              onSecondaryPress: (emoticImage) {},
                            )
                          : Center(
                            child: SizedBox.square(
                              dimension:
                                  MediaQuery.sizeOf(context).shortestSide *
                                      0.05,
                              child: CircularProgressIndicator(),
                            ),
                            
                    ),
                    onVisibilityChanged: (info) async {
                      if (info.visibleFraction > 0) {
                        if (!cachedImage.containsKey(images[index].imageUri)) {
                          await context
                              .read<EmotipicsListingCubit>()
                              .loadImageBytes(
                                imageToLoad: images[index].imageUri,
                              );
                        }
                      } else {
                        if (context.mounted) {
                          await context
                              .read<EmotipicsListingCubit>()
                              .unloadImageBytes(
                                imageToUnload: images[index].imageUri,
                              );
                        }
                      }
                    },
                  );
                },
              ),
            );
        }
      },
    );
  }
}
