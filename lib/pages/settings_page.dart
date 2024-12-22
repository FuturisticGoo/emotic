import 'package:emotic/core/init_setup.dart';
import 'package:emotic/cubit/settings_cubit.dart';
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
      child: BlocConsumer<SettingsCubit, SettingsState>(
        listener: (context, state) async {
          switch (state) {
            case SettingsLoaded(:final snackBarMessage)
                when snackBarMessage != null:
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(snackBarMessage),
                    duration: const Duration(milliseconds: 500),
                  ),
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
                    ListTile(
                      title: Text(
                        "Manage data",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
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
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('No'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Yes'),
                              ),
                            ],
                          ),
                        );
                        if (shouldClear == true && context.mounted) {
                          await context.read<SettingsCubit>().clearAllData();
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      title: Text(
                        "Backup and Restore",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                    ListTile(
                      title: const Text("Import"),
                      onTap: () async {
                        if (context.mounted) {
                          await context.read<SettingsCubit>().importData();
                        }
                      },
                    ),
                    ListTile(
                      title: const Text("Export"),
                      onTap: () async {
                        await context.read<SettingsCubit>().exportData();
                      },
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
      ),
    );
  }
}
