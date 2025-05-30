import 'package:emotic/core/emoticon.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/emoticons_data_editor_cubit.dart';
import 'package:emotic/cubit/emoticons_listing_cubit.dart';
import 'package:emotic/pages/emoticons_page_widgets/copyable_emoticon.dart';
import 'package:emotic/widgets_common/search_bar.dart';
import 'package:emotic/pages/emoticons_page_widgets/update_emoticon_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmoticonsListingWrapped extends StatelessWidget {
  const EmoticonsListingWrapped({
    super.key,
    required this.allTags,
    required this.controller,
    required this.emoticonsToShow,
    required this.settings,
  });

  final List<String> allTags;
  final TextEditingController controller;
  final List<Emoticon> emoticonsToShow;
  final GlobalSettings settings;

  @override
  Widget build(BuildContext context) {
    final emoticonListingViewId = "SingleChildScrollViewForEmoticons";
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GenericSearchBar(
            allTags: allTags,
            controller: controller,
            hintText: "Search by tag",
            onChange: (String text) {
              context.read<EmoticonsListingCubit>().searchEmoticons(
                    searchTerm: text,
                  );
            },
          ),
          const SizedBox(
            height: 20,
          ),
          Expanded(
            child: SingleChildScrollView(
              key: PageStorageKey(emoticonListingViewId),
              restorationId: emoticonListingViewId,
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 4.0,
                    runSpacing: 4.0,
                    children: emoticonsToShow.map(
                      (emoticon) {
                        return CopyableEmoticon(
                          emoticon: emoticon,
                          textSize: settings.emoticonsTextSize,
                          onLongPressed: (emoticon) async {
                            final result =
                                await showModalBottomSheet<BottomSheetResult?>(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) {
                                return UpdateEmoticonBottomSheet(
                                  newOrModifyEmoticon:
                                      NewOrModifyEmoticon.editExistingEmoticon(
                                    emoticon,
                                  ),
                                  isEditMode: true,
                                  allTags: allTags,
                                );
                              },
                            );
                            if (context.mounted) {
                              switch (result) {
                                case DeleteEmoticon(
                                      newOrModifyEmoticon: NewOrModifyEmoticon(
                                        :final oldEmoticon
                                      )
                                    )
                                    when oldEmoticon != null:
                                  await context
                                      .read<EmoticonsDataEditorCubit>()
                                      .deleteEmoticonsAndTags(
                                    emoticons: [oldEmoticon],
                                    tags: [],
                                  );
                                  if (context.mounted) {
                                    await context
                                        .read<EmoticonsListingCubit>()
                                        .loadEmoticons();
                                  }
                                case UpdateEmoticon(:final newOrModifyEmoticon):
                                  await context
                                      .read<EmoticonsDataEditorCubit>()
                                      .addNewEmoticons(
                                    newEmoticons: [newOrModifyEmoticon],
                                  );

                                  if (context.mounted) {
                                    await context
                                        .read<EmoticonsListingCubit>()
                                        .loadEmoticons();
                                  }
                                case TagClicked(:final tag):
                                  controller.text = tag;
                                case AddEmoticon():
                                case DeleteEmoticon():
                                case null:
                                  break;
                              }
                            }
                          },
                        );
                      },
                    ).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
