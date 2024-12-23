import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/emoticons_listing_cubit.dart';
import 'package:emotic/cubit/emoticons_listing_state.dart';
import 'package:emotic/widgets/copyable_emoticon.dart';
import 'package:emotic/widgets/search_bar.dart';
import 'package:emotic/widgets/update_emoticon_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmoticonsPage extends StatefulWidget {
  const EmoticonsPage({super.key});

  @override
  State<EmoticonsPage> createState() => _EmoticonsPageState();
}

class _EmoticonsPageState extends State<EmoticonsPage> {
  final emoticonListingViewId = "SingleChildScrollViewForEmoticons";
  final TextEditingController controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GlobalSettingsCubit, GlobalSettingsState>(
      builder: (context, state) {
        switch (state) {
          case GlobalSettingsInitial():
          case GlobalSettingsLoading():
            return const Center(
              child: CircularProgressIndicator.adaptive(),
            );
          case GlobalSettingsLoaded(:final settings):
            return BlocProvider(
              create: (context) => EmoticonsListingCubit(
                emoticonsRepository: sl(),
                shouldLoadFromAsset: settings.shouldReload,
              ),
              child: Scaffold(
                appBar: AppBar(
                  title: const Text("Emoticons"),
                  leading: DrawerButton(
                    onPressed: context.openRootScaffoldDrawer,
                  ),
                  actions: [
                    BlocConsumer<EmoticonsListingCubit, EmoticonsListingState>(
                      listener: (context, state) async {
                        if (state is EmoticonsListingLoaded &&
                            settings.shouldReload) {
                          await context
                              .read<GlobalSettingsCubit>()
                              .refreshSettings();
                        }
                      },
                      builder: (context, state) {
                        return PopupMenuButton(
                          enabled: state is EmoticonsListingLoaded,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text("Add emoticon"),
                              onTap: () async {
                                if (state
                                    case EmoticonsListingLoaded(
                                      :final allTags
                                    )) {
                                  final result = await showModalBottomSheet<
                                      BottomSheetResult?>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (context) {
                                      return UpdateEmoticonBottomSheet(
                                        allTags: allTags,
                                        isEditMode: false,
                                      );
                                    },
                                  );
                                  switch (result) {
                                    case AddEmoticon(:final emoticon)
                                        when context.mounted:
                                      context
                                          .read<EmoticonsListingCubit>()
                                          .saveEmoticon(
                                            emoticon: emoticon,
                                          );

                                    default:
                                      break;
                                  }
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                body: BlocBuilder<EmoticonsListingCubit, EmoticonsListingState>(
                  builder: (context, state) {
                    switch (state) {
                      case EmoticonsListingInitial():
                      case EmoticonsListingLoading():
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      case EmoticonsListingLoaded(
                          :final emoticonsToShow,
                          :final allTags
                        ):
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              EmoticonsSearchBar(
                                allTags: allTags,
                                controller: controller,
                                onChange: (String text) {
                                  context
                                      .read<EmoticonsListingCubit>()
                                      .searchEmoticons(
                                        searchTerm: text,
                                      );
                                },
                              ),
                              // TagFilter(
                              //   allTags: allTags,
                              // ),
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
                                              onLongPressed: (emoticon) async {
                                                final result =
                                                    await showModalBottomSheet<
                                                        BottomSheetResult?>(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  builder: (context) {
                                                    return UpdateEmoticonBottomSheet(
                                                      emoticon: emoticon,
                                                      isEditMode: true,
                                                      allTags: allTags,
                                                    );
                                                  },
                                                );
                                                if (context.mounted) {
                                                  switch (result) {
                                                    case DeleteEmoticon(
                                                        :final emoticon
                                                      ):
                                                      context
                                                          .read<
                                                              EmoticonsListingCubit>()
                                                          .deleteEmoticon(
                                                            emoticon: emoticon,
                                                          );

                                                    case UpdateEmoticon(
                                                        :final emoticon,
                                                        :final newEmoticon
                                                      ):
                                                      context
                                                          .read<
                                                              EmoticonsListingCubit>()
                                                          .saveEmoticon(
                                                            emoticon:
                                                                newEmoticon,
                                                            oldEmoticon:
                                                                emoticon,
                                                          );
                                                    case TagClicked(:final tag):
                                                      controller.text = tag;
                                                    case AddEmoticon():
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
                  },
                ),
              ),
            );
        }
      },
    );
  }
}
