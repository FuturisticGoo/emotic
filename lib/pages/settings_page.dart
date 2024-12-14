import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        leading: DrawerButton(
          onPressed: context.openRootScaffoldDrawer,
        ),
      ),
      body: const Center(
        child: Text("🛈 Under construction..."),
      ),
    );
  }
}
