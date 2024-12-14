import 'package:flutter/material.dart';

extension OpenRootScaffoldDrawer on BuildContext {
  void openRootScaffoldDrawer() {
    final ScaffoldState? scaffoldState =
        findRootAncestorStateOfType<ScaffoldState>();
    scaffoldState?.openDrawer();
  }
}
