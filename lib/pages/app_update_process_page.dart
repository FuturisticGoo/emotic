import 'package:emotic/core/app_update_ops.dart';
import 'package:emotic/core/constants.dart';
import 'package:emotic/core/logging.dart';
import 'package:emotic/core/routes.dart';
import 'package:emotic/core/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AppUpdateProcessPage extends StatelessWidget {
  const AppUpdateProcessPage({super.key});

  Future<void> doAppUpdateProcess(
      BuildContext context, GlobalSettingsState state) async {
    getLogger().config("Got settings state $state");
    switch (state) {
      case GlobalSettingsLoaded(:final settings) when settings.shouldReload:
        await performAppUpdateOperations(
          lastUsedVersion: settings.lastUsedVersion,
          currentRunningVersion: version,
        );

        if (context.mounted) {
          getLogger().config("Going to save and reload settings");
          await context.read<GlobalSettingsCubit>().saveSettings(
                settings.copyWith(
                  isFirstTime: false,
                  lastUsedVersion: version,
                ),
              );
        }
      case GlobalSettingsLoaded(:final settings) when !settings.shouldReload:
        context.go(Routes.emoticonsPage);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GlobalSettingsCubit, GlobalSettingsState>(
      builder: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => doAppUpdateProcess(context, state),
        );
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              SizedBox(
                height: 10,
              ),
              Text("Updating stuff ● . ◉"),
            ],
          ),
        );
      },
    );
  }
}
