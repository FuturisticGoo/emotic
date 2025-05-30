import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/pages/about_page_widgets/about_foreground.dart';
import 'package:flutter/material.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About"),
        leading: DrawerButton(
          onPressed: context.openRootScaffoldDrawer,
        ),
      ),
      body: const Center(
        child: Stack(
          children: [
            AboutForeground(),
          ],
        ),
      ),
    );
  }
}
