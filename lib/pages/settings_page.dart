import 'package:emotic/core/app_theme.dart';
import 'package:emotic/core/constants.dart';
import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/cubit/settings_cubit.dart';
import 'package:emotic/widgets/list_tile_heading.dart';
import 'package:emotic/widgets/show_message.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsCubit(
        emoticonsRepository: sl(),
      ),
      child: BlocBuilder<GlobalSettingsCubit, GlobalSettingsState>(
        builder: (context, globalSettingstate) {
          switch (globalSettingstate) {
            case GlobalSettingsLoaded(:final settings):
              return BlocConsumer<SettingsCubit, SettingsState>(
                listener: (context, state) async {
                  switch (state) {
                    case SettingsLoaded(:final snackBarMessage)
                        when snackBarMessage != null:
                      if (context.mounted) {
                        showSnackBar(context, text: snackBarMessage);
                      }
                    case SettingsLoaded(:final alertMessage)
                        when alertMessage != null:
                      if (context.mounted) {
                        showAlertDialog(
                          context,
                          title: "Error",
                          content: alertMessage,
                          onPressed: () {},
                        );
                      }
                    default:
                      break;
                  }
                },
                builder: (context, state) {
                  switch (state) {
                    case SettingsLoaded():
                      return Scaffold(
                        appBar: AppBar(
                          title: const Text("Settings"),
                          leading: DrawerButton(
                            onPressed: context.openRootScaffoldDrawer,
                          ),
                        ),
                        body: ListView(
                          children: [
                            const ListTileHeading(
                              text: "Manage data",
                            ),
                            ListTile(
                              title: const Text("Restore all emoticons"),
                              onTap: () async {
                                await context
                                    .read<SettingsCubit>()
                                    .loadEmoticonsFromAsset();
                              },
                            ),
                            ListTile(
                              title: const Text("Clear all data"),
                              onTap: () async {
                                final shouldClear = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Confirm"),
                                    content: const Text(
                                      "Are you sure you want to delete all data?",
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('No'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Yes'),
                                      ),
                                    ],
                                  ),
                                );
                                if (shouldClear == true && context.mounted) {
                                  await context
                                      .read<SettingsCubit>()
                                      .clearAllData();
                                }
                              },
                            ),
                            const Divider(),
                            const ListTileHeading(
                              text: "Backup and Restore",
                            ),
                            ListTile(
                              title: const Text("Import"),
                              onTap: () async {
                                if (context.mounted) {
                                  await context
                                      .read<SettingsCubit>()
                                      .importData();
                                }
                              },
                            ),
                            ListTile(
                              title: const Text("Export"),
                              onTap: () async {
                                await context
                                    .read<SettingsCubit>()
                                    .exportData();
                              },
                            ),
                            const Divider(),
                            const ListTileHeading(text: "Theme & UI"),
                            ListTile(
                              title: Text("Theme mode"),
                              trailing: DropdownMenu(
                                initialSelection: settings.emoticThemeMode,
                                onSelected: (emoticThemeMode) async {
                                  await context
                                      .read<GlobalSettingsCubit>()
                                      .saveSettings(
                                        settings.copyWith(
                                          emoticThemeMode: emoticThemeMode,
                                        ),
                                      );
                                  if (context.mounted) {
                                    await context
                                        .read<GlobalSettingsCubit>()
                                        .refreshSettings();
                                  }
                                },
                                dropdownMenuEntries: [
                                  DropdownMenuEntry(
                                    value: EmoticThemeMode.system,
                                    label: "System",
                                  ),
                                  DropdownMenuEntry(
                                    value: EmoticThemeMode.light,
                                    label: "Light",
                                  ),
                                  DropdownMenuEntry(
                                    value: EmoticThemeMode.dark,
                                    label: "Dark",
                                  ),
                                  DropdownMenuEntry(
                                    value: EmoticThemeMode.black,
                                    label: "Black",
                                  ),
                                ],
                              ),
                            ),
                            ListTile(
                              title: Text("Emoticon text size"),
                              trailing: DropdownMenu(
                                initialSelection: settings.emoticonsTextSize,
                                onSelected: (textSize) async {
                                  await context
                                      .read<GlobalSettingsCubit>()
                                      .saveSettings(
                                        settings.copyWith(
                                          emoticonsTextSize: textSize,
                                        ),
                                      );
                                  if (context.mounted) {
                                    await context
                                        .read<GlobalSettingsCubit>()
                                        .refreshSettings();
                                  }
                                },
                                dropdownMenuEntries: [
                                  null,
                                  ...Iterable.generate(
                                    emoticonsTextSizeUpperLimit -
                                        emoticonsTextSizeLowerLimit +
                                        1,
                                    (index) =>
                                        index + emoticonsTextSizeLowerLimit,
                                  )
                                ].map(
                                  (e) {
                                    if (e == null) {
                                      return DropdownMenuEntry(
                                        value: null,
                                        label: "Default",
                                      );
                                    } else {
                                      return DropdownMenuEntry(
                                        value: e,
                                        label: e.toString(),
                                      );
                                    }
                                  },
                                ).toList(),
                              ),
                            ),
                            ListTile(
                              title: Text("Emotipics column count"),
                              trailing: DropdownMenu(
                                initialSelection: settings.emotipicsColumnCount,
                                onSelected: (colCount) async {
                                  await context
                                      .read<GlobalSettingsCubit>()
                                      .saveSettings(
                                        settings.copyWith(
                                          emotipicsColumnCount: colCount,
                                        ),
                                      );
                                  if (context.mounted) {
                                    await context
                                        .read<GlobalSettingsCubit>()
                                        .refreshSettings();
                                  }
                                },
                                dropdownMenuEntries: [
                                  null,
                                  ...Iterable.generate(
                                    emotipicsColCountUpperLimit -
                                        emotipicsColCountLowerLimit +
                                        1,
                                    (index) =>
                                        index + emotipicsColCountLowerLimit,
                                  )
                                ].map(
                                  (e) {
                                    if (e == null) {
                                      return DropdownMenuEntry(
                                        value: null,
                                        label: "Default",
                                      );
                                    } else {
                                      return DropdownMenuEntry(
                                        value: e,
                                        label: e.toString(),
                                      );
                                    }
                                  },
                                ).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    case SettingsInitial():
                    case SettingsLoading():
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                  }
                },
              );
            case GlobalSettingsInitial():
            case GlobalSettingsLoading():
              return const Center(
                child: CircularProgressIndicator(),
              );
          }
        },
      ),
    );
  }
}
