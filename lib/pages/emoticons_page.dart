import 'package:emotic/core/emoticon.dart';
import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/core/routes.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/emoticons_listing_cubit.dart';
import 'package:emotic/cubit/emoticons_listing_state.dart';
import 'package:emotic/widgets/copyable_emoticon.dart';
import 'package:emotic/widgets/search_bar.dart';
import 'package:emotic/widgets/update_emoticon_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
      builder: (context, state) {
        switch (state) {
          case GlobalSettingsInitial():
          case GlobalSettingsLoading():
            return const Center(
              child: CircularProgressIndicator.adaptive(),
            );
          case GlobalSettingsLoaded():
            return BlocProvider(
              create: (context) => EmoticonsListingCubit(
                emoticonsRepository: sl(),
              ),
              child: Scaffold(
                appBar: AppBar(
                  title: const Text("Emoticons"),
                  leading: DrawerButton(
                    onPressed: context.openRootScaffoldDrawer,
                  ),
                  actions: [
                    BlocBuilder<EmoticonsListingCubit, EmoticonsListingState>(
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
                                        newOrModifyEmoticon:
                                            NewOrModifyEmoticon.newEmoticon(),
                                      );
                                    },
                                  );
                                  switch (result) {
                                    case AddEmoticon(:final newOrModifyEmoticon)
                                        when context.mounted:
                                      context
                                          .read<EmoticonsListingCubit>()
                                          .saveEmoticon(
                                              newOrModifyEmoticon:
                                                  newOrModifyEmoticon);

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
                                                      newOrModifyEmoticon:
                                                          NewOrModifyEmoticon
                                                              .fromExistingEmoticon(
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
                                                          newOrModifyEmoticon:
                                                              NewOrModifyEmoticon(
                                                            :final oldEmoticon
                                                          )
                                                        )
                                                        when oldEmoticon !=
                                                            null:
                                                      context
                                                          .read<
                                                              EmoticonsListingCubit>()
                                                          .deleteEmoticon(
                                                            emoticon:
                                                                oldEmoticon,
                                                          );

                                                    case UpdateEmoticon(
                                                        :final newOrModifyEmoticon
                                                      ):
                                                      context
                                                          .read<
                                                              EmoticonsListingCubit>()
                                                          .saveEmoticon(
                                                            newOrModifyEmoticon:
                                                                newOrModifyEmoticon,
                                                          );
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
                  },
                ),
              ),
            );
        }
      },
    );
  }
}
