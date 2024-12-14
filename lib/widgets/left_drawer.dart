import 'package:emotic/core/routes.dart';
import 'package:emotic/pages/about_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LeftDrawer extends StatefulWidget {
  const LeftDrawer({super.key});

  @override
  State<LeftDrawer> createState() => _LeftDrawerState();
}

class _LeftDrawerState extends State<LeftDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            child: Center(
              child: EmoticLogo(),
            ),
          ),
          ListTile(
            title: const Text("Emoticons"),
            onTap: () {
              Navigator.of(context).pop();
              context.go(Routes.emoticonsPage);
            },
          ),
          ListTile(
            title: const Text("Tag link editor"),
            onTap: () {
              Navigator.of(context).pop();
              context.go(Routes.tagLinkEditorPage);
            },
          ),
          ListTile(
            title: const Text("Settings"),
            onTap: () {
              Navigator.of(context).pop();
              context.go(Routes.settingsPage);
            },
          ),
          ListTile(
            title: const Text("About"),
            onTap: () {
              Navigator.of(context).pop();
              context.go(Routes.aboutPage);
            },
          ),
        ],
      ),
    );
  }
}
