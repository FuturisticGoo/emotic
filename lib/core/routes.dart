import 'package:emotic/core/logging.dart';
import 'package:emotic/pages/about_page.dart';
import 'package:emotic/pages/app_update_process_page.dart';
import 'package:emotic/pages/emoticons_page.dart';
import 'package:emotic/pages/emotipics_page.dart';
import 'package:emotic/pages/fancy_text_page.dart';
import 'package:emotic/pages/settings_page.dart';
import 'package:emotic/widgets_common/left_drawer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Routes {
  static const emoticonsPage = "/emoticons";
  static const emotipicsPage = "/emotipics";
  static const fancyTextPage = "/fancyText";
  static const settingsPage = "/settings";
  static const aboutPage = "/about";
  static const updatingPage = "/updating";
  static final _rootNavKey = GlobalKey<NavigatorState>();
  static final _shellNavKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavKey,
    initialLocation: emoticonsPage,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            // Using a root Scaffold to supply a common left drawer to all pages
            // but without using the same AppBar, so that each page can have
            // its own unique AppBar
            drawer: const LeftDrawer(),
            body: navigationShell,
          );
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavKey,
            routes: [
              GoRoute(
                path: emoticonsPage,
                builder: (context, state) {
                  getLogger().fine("Going to EmoticonsPage");
                  return EmoticonsPage();
                },
              ),
              GoRoute(
                path: fancyTextPage,
                builder: (context, state) {
                  getLogger().fine("Going to FancyTextPage");
                  return const FancyTextPage();
                },
              ),
              GoRoute(
                path: emotipicsPage,
                builder: (context, state) {
                  getLogger().fine("Going to EmotiPicsPage");
                  return const EmotipicsPage();
                },
              ),
              GoRoute(
                path: settingsPage,
                builder: (context, state) {
                  getLogger().fine("Going to SettingsPage");
                  return const SettingsPage();
                },
              ),
              GoRoute(
                path: aboutPage,
                builder: (context, state) {
                  getLogger().fine("Going to AboutPage");
                  return const AboutPage();
                },
              ),
              GoRoute(
                path: updatingPage,
                builder: (context, state) {
                  getLogger().fine("Going to AppUpdateProcessPage");
                  return const AppUpdateProcessPage();
                },
              ),
            ],
          )
        ],
      ),
    ],
  );
}
