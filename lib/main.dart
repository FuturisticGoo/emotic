import 'package:emotic/core/init_setup.dart';
import 'package:emotic/core/settings.dart';
import 'package:emotic/pages/emotic_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Emotic',
        theme: ThemeData(
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const EmoticHomePage(),
      ),
    );
  }
}
