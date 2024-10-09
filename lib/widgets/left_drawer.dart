import 'package:flutter/material.dart';

class LeftDrawer extends StatelessWidget {
  const LeftDrawer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "OwO",
                  style: Theme.of(context).textTheme.displayLarge,
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text("Emoticons"),
            onTap: () {},
          ),
          ListTile(
            title: Text("Tag link editor"),
            onTap: () {},
          ),
          ListTile(
            title: Text("Settings"),
            onTap: () {},
          ),
          ListTile(
            title: Text("About"),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
