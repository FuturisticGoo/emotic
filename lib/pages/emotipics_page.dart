import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/cubit/emotipics_cubit.dart';
import 'package:emotic/widgets/copyable_image.dart';
import 'package:emotic/widgets/search_bar.dart';
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
  Map<Uri, Image> cachedImage = {};

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EmotipicsListingCubit(
        imageRepository: sl(),
      ),
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
                      await context.read<EmotipicsListingCubit>().pickImages();
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
              BlocBuilder<EmotipicsListingCubit, EmotipicsListingState>(
                builder: (context, state) {
                  switch (state) {
                    case EmotipicsListingInitial():
                    case EmotipicsListingLoading():
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    case EmotipicsListingError():
                      return Center(
                        child: Text("Error loading images"),
                      );
                    case EmotipicsListingLoaded(
                        :final images,
                        :final visibleImageData
                      ):
                      final aspectRatioCount =
                          (MediaQuery.sizeOf(context).aspectRatio * 5).floor();
                      return Expanded(
                        child: GridView.builder(
                          shrinkWrap: true,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                aspectRatioCount > 8 ? 8 : aspectRatioCount,
                          ),
                          itemCount: images.length,
                          restorationId: "imagesListThing",
                          itemBuilder: (context, index) {
                            final currentImage = images[index];
                            final width = (MediaQuery.sizeOf(context).width *
                                    1 /
                                    ((MediaQuery.sizeOf(context).aspectRatio *
                                            5)
                                        .floor()))
                                .toInt();
                            final imageBytes =
                                visibleImageData[currentImage.imageUri];
                            if (cachedImage[currentImage.imageUri] == null &&
                                imageBytes != null) {
                              cachedImage[currentImage.imageUri] = Image.memory(
                                imageBytes,
                                cacheWidth: width,
                              );
                            }
                            final currentCachedImage =
                                cachedImage[currentImage.imageUri];
                            return VisibilityDetector(
                              key: Key(images[index].toString()),
                              child: Padding(
                                padding: EdgeInsets.all(8),
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
                                        child: CircularProgressIndicator(),
                                      ),
                              ),
                              onVisibilityChanged: (info) async {
                                if (info.visibleFraction > 0) {
                                  if (!cachedImage
                                      .containsKey(images[index].imageUri)) {
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
