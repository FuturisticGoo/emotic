import 'package:emotic/core/constants.dart';
import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/routes.dart';
import 'package:emotic/core/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/init_setup.dart' as init;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSetup();

  runApp(const EmoticApp());
}

class EmoticApp extends StatelessWidget {
  const EmoticApp({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsCubit(
        settingsSource: init.sl(),
      ),
      child: BlocListener<SettingsCubit, SettingsState>(
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
        child: DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              title: 'Emotic',
              theme: ThemeData(
                colorScheme: lightDynamic,
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                colorScheme: darkDynamic,
                brightness: Brightness.dark,
                useMaterial3: true,
              ),
              themeMode: ThemeMode.system,
              routerConfig: Routes.router,
            );
          },
        ),
      ),
    );
  }
}
