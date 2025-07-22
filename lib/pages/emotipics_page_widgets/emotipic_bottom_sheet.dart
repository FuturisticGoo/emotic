import 'package:emotic/core/emotic_image.dart';
import 'package:emotic/core/image_data.dart';
import 'package:emotic/cubit/emotipics_cubit.dart';
import 'package:emotic/widgets_common/delete_confirmation.dart';
import 'package:emotic/widgets_common/read_list_of_string_from_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart' as fp;

sealed class EmotipicBottomSheetResult {
  const EmotipicBottomSheetResult();
}

class DeleteEmotipic extends EmotipicBottomSheetResult {
  final EmoticImage emoticImage;
  const DeleteEmotipic({required this.emoticImage});
}

class UpdateEmotipic extends EmotipicBottomSheetResult {
  final NewOrModifyEmoticImage modifyEmotipic;
  const UpdateEmotipic({
    required this.modifyEmotipic,
  });
}

class ShareEmotipic extends EmotipicBottomSheetResult {
  final EmoticImage selectedImage;
  const ShareEmotipic({
    required this.selectedImage,
  });
}

class EmotipicTagClicked extends EmotipicBottomSheetResult {
  final String tag;
  const EmotipicTagClicked({
    required this.tag,
  });
}

class UpdateEmotipicBottomSheet extends StatefulWidget {
  const UpdateEmotipicBottomSheet({
    super.key,
    required this.allTags,
    required this.emoticImage,
    required this.loadImageBytes,
    required this.unloadImageBytes,
  });
  final EmoticImage emoticImage;
  final List<String> allTags;
  final Future<void> Function(
    Uri imageToLoad,
    ImageReprConfig? imageReprConfig,
  ) loadImageBytes;
  final Future<void> Function(
    Uri imageToUnload,
  ) unloadImageBytes;
  @override
  State<UpdateEmotipicBottomSheet> createState() =>
      _UpdateEmotipicBottomSheetState();
}

class _UpdateEmotipicBottomSheetState extends State<UpdateEmotipicBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController emotipicNotesTextController;
  late final AnimationController animationController;
  bool fullQualityLoaded = false;
  bool readOnlyMode = true;
  Map<String, bool> tagsSelection = {};
  @override
  void initState() {
    super.initState();
    emotipicNotesTextController = TextEditingController(
      text: widget.emoticImage.note,
    );
    animationController = AnimationController(vsync: this);
    tagsSelection = Map.fromEntries(
      widget.allTags.map(
        (tag) => MapEntry(
          tag,
          widget.emoticImage.tags.contains(tag),
        ),
      ),
    );
  }

  @override
  void dispose() {
    animationController.dispose();
    emotipicNotesTextController.dispose();
    widget.unloadImageBytes(widget.emoticImage.imageUri);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isSmallScreen = screenHeight < 640;
    final imageHeight = screenHeight * 0.5;
    return BlocBuilder<EmotipicsListingCubit, EmotipicsListingState>(
      builder: (context, state) {
        if (!fullQualityLoaded) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) async {
              await widget.loadImageBytes(
                widget.emoticImage.imageUri,
                FlutterImageWidgetReprConfig.full(
                  preferredHeight: imageHeight.toInt(),
                ),
              );
              fullQualityLoaded = true;
            },
          );
        }

        final Widget imageWidget;
        switch (state) {
          case EmotipicsListingLoaded(:final visibleImageData):
            final currentImageResult =
                visibleImageData[widget.emoticImage.imageUri];
            switch (currentImageResult) {
              case fp.Right(
                  value: FlutterImageWidgetImageRepr(
                    imageWidget: final imageWidgetValue
                  )
                ):
                imageWidget = imageWidgetValue;

              case fp.Left(:final value):
                imageWidget = Center(child: Text(value.message));
              case fp.Right():
              case null:
                imageWidget = Center(child: Text("Unable to load image"));
            }
          default:
            imageWidget = Center(child: Text("Unable to load image"));
        }
        return BottomSheet(
          animationController: animationController,
          showDragHandle: true,
          enableDrag: false,
          constraints: BoxConstraints.expand(
            height: screenHeight,
            // height: isSmallScreen ? screenHeight : screenHeight * 0.7,
          ),
          onClosing: () {},
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            switch (readOnlyMode) {
                              true => "Emotipic",
                              false => "Modify Emotipic",
                            },
                          ),
                          SizedBox(
                            height: isSmallScreen ? 10 : 20,
                          ),
                          SizedBox(
                            height: imageHeight,
                            // width: double.infinity,
                            child: imageWidget,
                          ),
                          SizedBox(
                            height: isSmallScreen ? 15 : 30,
                          ),
                          TagsSelection(
                            isSmallScreen: isSmallScreen,
                            tagsSelection: readOnlyMode
                                ? tagsSelection
                                : {
                                    ...tagsSelection,
                                    "+": false,
                                  },
                            onSelect: (tag, selected) async {
                              if (tag == "+") {
                                final newTags = await readTags(context);
                                if (newTags != null) {
                                  setState(
                                    () {
                                      tagsSelection.addEntries(
                                        newTags.map(
                                          (newTag) => MapEntry(newTag, true),
                                        ),
                                      );
                                    },
                                  );
                                }
                              } else if (readOnlyMode) {
                                Navigator.pop<EmotipicBottomSheetResult>(
                                  context,
                                  EmotipicTagClicked(
                                    tag: tag,
                                  ),
                                );
                              } else {
                                setState(() {
                                  tagsSelection[tag] = selected;
                                });
                              }
                            },
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          TextField(
                            readOnly: readOnlyMode,
                            // expands: true,
                            maxLines: null,
                            controller: emotipicNotesTextController,

                            decoration: const InputDecoration(
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              border: OutlineInputBorder(),
                              label: Text("Note"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  Row(
                    children: [
                      ...switch (readOnlyMode) {
                        true => [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.only(),
                              ),
                              onPressed: () async {
                                Navigator.pop<EmotipicBottomSheetResult>(
                                  context,
                                  ShareEmotipic(
                                    selectedImage: widget.emoticImage,
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.share,
                              ),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: () {
                                setState(() {
                                  readOnlyMode = false;
                                });
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text("Edit"),
                            ),
                          ],
                        false => [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.only(),
                              ),
                              onPressed: () async {
                                if (await confirmDeletionDialog(
                                          context,
                                          titleText: "Delete image?",
                                        ) ==
                                        true &&
                                    context.mounted) {
                                  Navigator.pop<EmotipicBottomSheetResult>(
                                    context,
                                    DeleteEmotipic(
                                      emoticImage: widget.emoticImage,
                                    ),
                                  );
                                }
                              },
                              child: Icon(
                                Icons.delete,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const Spacer(
                              flex: 10,
                            ),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text("Cancel"),
                            ),
                            const Flexible(
                              flex: 1,
                              child: SizedBox(
                                width: 20,
                              ),
                            ),
                            FilledButton(
                              onPressed: () {
                                final updatedEmoticon =
                                    NewOrModifyEmoticImage.modify(
                                  note: emotipicNotesTextController.text,
                                  tags: tagsSelection.entries
                                      .where(
                                        (tag) => tag.value,
                                      )
                                      .map(
                                        (e) => e.key,
                                      )
                                      .toList(),
                                  oldImage: widget.emoticImage,
                                  isExcluded: false,
                                );

                                Navigator.pop<EmotipicBottomSheetResult>(
                                  context,
                                  UpdateEmotipic(
                                    modifyEmotipic: updatedEmoticon,
                                  ),
                                );
                              },
                              child: const Text("Save"),
                            )
                          ],
                      },
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class TagsSelection extends StatefulWidget {
  final bool isSmallScreen;
  final Map<String, bool> tagsSelection;
  final void Function(String tag, bool selected) onSelect;
  const TagsSelection({
    super.key,
    required this.isSmallScreen,
    required this.tagsSelection,
    required this.onSelect,
  });

  @override
  State<TagsSelection> createState() => _TagsSelectionState();
}

class _TagsSelectionState extends State<TagsSelection> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: true,
      // expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        label: Text("Tags"),
        // contentPadding: EdgeInsets.all(0),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: widget.tagsSelection.isEmpty ? "No tags found" : null,
        prefix: Wrap(
          spacing: 5.0,
          runSpacing: 5.0,
          children: widget.tagsSelection.keys
              .map(
                (tag) => FilterChip(
                  label: Text(tag),
                  selected: widget.tagsSelection[tag] ?? false,
                  onSelected: (selected) => widget.onSelect(tag, selected),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
