import 'package:emotic/core/constants.dart';
import 'package:emotic/core/emoticon.dart';
import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/emoticons_listing_cubit.dart';
import 'package:emotic/cubit/emoticons_listing_state.dart';
import 'package:emotic/widgets/copyable_emoticon.dart';
import 'package:emotic/widgets/update_emoticon_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmoticHomePage extends StatelessWidget {
  const EmoticHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state is SettingsLoaded) {
          if (state.settings.isFirstTime) {
            context.read<SettingsCubit>().saveSettings(
                  const Settings(
                    isFirstTime: false,
                    lastUsedVersion: version,
                  ),
                );
          }
        }
      },
      builder: (context, state) {
        switch (state) {
          case SettingsInitial():
          case SettingsLoading():
            return const Center(
              child: CircularProgressIndicator.adaptive(),
            );
          case SettingsLoaded(:final settings):
            return BlocProvider(
              create: (context) => EmoticonsListingCubit(
                emoticonsRepository: sl(),
                shouldLoadFromAsset: settings.isFirstTime || settings.isUpdated,
              ),
              child: Scaffold(
                appBar: AppBar(
                  title: const Text("Emotic"),
                  actions: [
                    BlocBuilder<EmoticonsListingCubit, EmoticonsListingState>(
                      builder: (context, state) {
                        return PopupMenuButton(
                          enabled: state is EmoticonsListingLoaded,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text("Refresh"),
                              onTap: () {
                                context
                                    .read<EmoticonsListingCubit>()
                                    .loadEmoticons(shouldLoadFromAsset: false);
                              },
                            ),
                            PopupMenuItem(
                              child: const Text("Add emoticon"),
                              onTap: () async {
                                if (state
                                    case EmoticonsListingLoaded(
                                      :final allTags
                                    )) {
                                  final newEmoticon =
                                      await showModalBottomSheet<Emoticon?>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (context) {
                                      return UpdateEmoticonBottomSheet(
                                        allTags: allTags,
                                      );
                                    },
                                  );
                                  if (newEmoticon != null && context.mounted) {
                                    context
                                        .read<EmoticonsListingCubit>()
                                        .saveEmoticon(
                                          emoticon: newEmoticon,
                                        );
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
                              TextField(
                                autofocus: false,
                                decoration: InputDecoration(
                                  hintText: "Search by tag",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  suffixIcon: const Icon(Icons.search),
                                ),
                                onChanged: (value) {
                                  context
                                      .read<EmoticonsListingCubit>()
                                      .searchEmoticons(searchTerm: value);
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
                                              onEditPressed: (emoticon) async {
                                                final editedEmoticon =
                                                    await showModalBottomSheet<
                                                        Emoticon?>(
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
                                                if (editedEmoticon != null &&
                                                    context.mounted) {
                                                  context
                                                      .read<
                                                          EmoticonsListingCubit>()
                                                      .saveEmoticon(
                                                        emoticon:
                                                            editedEmoticon,
                                                        oldEmoticon: emoticon,
                                                      );
                                                }
                                              },
                                              onDeletePressed: (emoticon) {
                                                context
                                                    .read<
                                                        EmoticonsListingCubit>()
                                                    .deleteEmoticon(
                                                      emoticon: emoticon,
                                                    );
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

/*
// Might use it later
class TagFilter extends StatefulWidget {
  final List<String> allTags;
  const TagFilter({
    super.key,
    required this.allTags,
  });

  @override
  State<TagFilter> createState() => _TagFilterState();
}

class _TagFilterState extends State<TagFilter> {
  Map<String, bool> tagSelection = {};
  @override
  void initState() {
    super.initState();
    tagSelection = Map.fromEntries(
      widget.allTags.map(
        (tag) => MapEntry(tag, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 5,
        children: tagSelection.keys
            .map(
              (tag) => FilterChip(
                label: Text(tag),
                selected: tagSelection[tag] ?? false,
                onSelected: (selected) async {
                  setState(() {
                    tagSelection[tag] = selected;
                  });
                },
              ),
            )
            .toList(),
      ),
    );
  }
}
*/