import 'package:emotic/core/app_theme.dart';
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
      create: (context) => GlobalSettingsCubit(
        settingsSource: init.sl(),
      ),
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Emotic',
            theme: getAppTheme(
              colorScheme: lightDynamic,
              brightness: Brightness.light,
            ),
            darkTheme: getAppTheme(
              colorScheme: darkDynamic,
              brightness: Brightness.dark,
            ),
            themeMode: ThemeMode.system,
            routerConfig: Routes.router,
          );
        },
      ),
    );
  }
}
