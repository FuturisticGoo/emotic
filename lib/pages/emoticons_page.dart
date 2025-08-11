import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/routes.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/emoticons_data_editor_cubit.dart';
import 'package:emotic/cubit/emoticons_data_editor_state.dart';
import 'package:emotic/cubit/emoticons_listing_cubit.dart';
import 'package:emotic/cubit/emoticons_listing_state.dart';
import 'package:emotic/pages/emoticons_page_widgets/emoticons_app_bar.dart';
import 'package:emotic/pages/emoticons_page_widgets/emoticons_editing_view.dart';
import 'package:emotic/pages/emoticons_page_widgets/emoticons_listing_wrapped.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class EmoticonsPage extends StatefulWidget {
  const EmoticonsPage({super.key});

  @override
  State<EmoticonsPage> createState() => _EmoticonsPageState();
}

class _EmoticonsPageState extends State<EmoticonsPage> {
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
          case GlobalSettingsLoaded(:final settings):
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (context) => EmoticonsListingCubit(
                    emoticonsRepository: sl(),
                  ),
                ),
                BlocProvider(
                  create: (context) => EmoticonsDataEditorCubit(
                    emoticonsRepository: sl(),
                  ),
                ),
              ],
              child: BlocListener<EmoticonsDataEditorCubit,
                  EmoticonsDataEditorState>(
                listener: (context, state) async {
                  await context.read<EmoticonsListingCubit>().loadEmoticons();
                },
                listenWhen: (previous, current) {
                  return previous is EmoticonsDataEditorEditing &&
                      current is EmoticonsDataEditorNotEditing;
                },
                child: SafeArea(
                  child: Scaffold(
                    appBar: EmoticonsAppBar(),
                    body: BlocBuilder<EmoticonsListingCubit,
                        EmoticonsListingState>(
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
                            return BlocBuilder<EmoticonsDataEditorCubit,
                                EmoticonsDataEditorState>(
                              builder: (context, state) {
                                switch (state) {
                                  case EmoticonsDataEditorInitial():
                                  case EmoticonsDataEditorLoading():
                                    return Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  case EmoticonsDataEditorNotEditing():
                                    return EmoticonsListingWrapped(
                                      allTags: allTags,
                                      controller: controller,
                                      emoticonsToShow: emoticonsToShow,
                                      settings: settings,
                                    );

                                  case EmoticonsDataEditorEditing():
                                    return EmoticonsEditingView(
                                      state: state,
                                    );
                                }
                              },
                            );
                        }
                      },
                    ),
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}
