import 'package:emotic/pages/about_page.dart';
import 'package:emotic/pages/emoticons_page.dart';
import 'package:emotic/pages/settings_page.dart';
import 'package:emotic/pages/tag_editor_page.dart';
import 'package:emotic/widgets/left_drawer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Routes {
  static const emoticonsPage = "/emoticons";
  static const tagEditorPage = "/tagEditor";
  static const settingsPage = "/settings";
  static const aboutPage = "/about";

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
                  return const EmoticonsPage();
                },
              ),
              GoRoute(
                path: tagEditorPage,
                builder: (context, state) {
                  return const TagEditorPage();
                },
              ),
              GoRoute(
                path: settingsPage,
                builder: (context, state) {
                  return const SettingsPage();
                },
              ),
              GoRoute(
                path: aboutPage,
                builder: (context, state) {
                  return const AboutPage();
                },
              ),
            ],
          )
        ],
      ),
    ],
  );
}
