import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/core/routes.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/fancy_text_cubit.dart';
import 'package:emotic/pages/fancy_text_page_widgets/fancy_text_widget.dart';
import 'package:emotic/widgets_common/blank_icon_space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class FancyTextPage extends StatefulWidget {
  const FancyTextPage({super.key});

  @override
  State<FancyTextPage> createState() => _FancyTextPageState();
}

class _FancyTextPageState extends State<FancyTextPage> {
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
          // Refer to emoticons_page.dart:47
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
            return BlocProvider(
              create: (context) => FancyTextCubit(
                fancyTextRepository: sl(),
              ),
              child: SafeArea(
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text("Fancy Text"),
                    leading: DrawerButton(
                      onPressed: context.openRootScaffoldDrawer,
                    ),
                    actions: [
                      PopupMenuButton(
                        itemBuilder: (context) {
                          return [
                            PopupMenuItem(
                              child: BlocBuilder<GlobalSettingsCubit,
                                  GlobalSettingsState>(
                                builder: (context, state) {
                                  final int fontSize;
                                  switch (state) {
                                    case GlobalSettingsLoaded(:final settings):
                                      fontSize = settings.fancyTextSize ?? 12;
                                    default:
                                      fontSize = 12;
                                  }
                                  return ListTile(
                                    leading: BlankIconSpace(),
                                    title: IntrinsicWidth(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Text("Zoom"),
                                          const Spacer(),
                                          ActionChip(
                                            onPressed: () async {
                                              final newfontSize = fontSize - 1;
                                              await context
                                                  .read<GlobalSettingsCubit>()
                                                  .changeFancyTextFontSize(
                                                    newSize: newfontSize,
                                                  );
                                            },
                                            labelPadding: EdgeInsets.fromLTRB(
                                              2,
                                              0,
                                              2,
                                              0,
                                            ),
                                            padding: EdgeInsets.all(0),
                                            label: Icon(Icons.remove),
                                          ),
                                          const SizedBox(width: 4),
                                          Text("$fontSize"),
                                          const SizedBox(width: 4),
                                          ActionChip(
                                            onPressed: () async {
                                              final newfontSize = fontSize + 1;
                                              await context
                                                  .read<GlobalSettingsCubit>()
                                                  .changeFancyTextFontSize(
                                                    newSize: newfontSize,
                                                  );
                                            },
                                            labelPadding: EdgeInsets.fromLTRB(
                                              2,
                                              0,
                                              2,
                                              0,
                                            ),
                                            padding: EdgeInsets.all(0),
                                            label: Icon(Icons.add),
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                  body: BlocBuilder<FancyTextCubit, FancyTextState>(
                    builder: (context, state) {
                      switch (state) {
                        case FancyTextInitial():
                        case FancyTextLoading():
                          return Center(
                            child: CircularProgressIndicator(),
                          );
                        case FancyTextLoaded(
                            :final inputText,
                            :final textTransforms
                          ):
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                TextFormField(
                                  controller: controller,
                                  minLines: 1,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: "Input text",
                                    hintText: "Type something here",
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        controller.text = "";
                                        context
                                            .read<FancyTextCubit>()
                                            .changeText(text: "");
                                      },
                                      icon: Icon(Icons.close),
                                    ),
                                  ),
                                  onChanged: (newText) {
                                    context
                                        .read<FancyTextCubit>()
                                        .changeText(text: newText);
                                  },
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: textTransforms.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: FancyTextWidget(
                                          fancyTextTransformer:
                                              textTransforms[index],
                                          inputText: inputText,
                                          textSize: settings.fancyTextSize,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                      }
                    },
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}
