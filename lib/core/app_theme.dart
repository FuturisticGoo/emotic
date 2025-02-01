import 'package:flutter/material.dart';

ThemeData getAppTheme({
  required ColorScheme? colorScheme,
  required Brightness brightness,
  bool isPureBlack = false,
}) {
  return ThemeData(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        // Set the predictive back transitions for Android.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
    fontFamily: "Noto Sans",
    fontFamilyFallback: const [
      "sans-serif",
      "Roboto",
    ],
    useMaterial3: true,
    colorScheme: isPureBlack
        ? colorScheme?.copyWith(
            surface: Colors.black,
            surfaceContainer: _pureBlackSurface, // Context menu background
            surfaceContainerLow:
                _pureBlackSurface, // Left drawer, bottom sheet background
            surfaceContainerHigh: _pureBlackSurface,
            surfaceContainerHighest: _pureBlackSurface,
            surfaceContainerLowest: _pureBlackSurface,
          )
        : colorScheme,
    brightness: brightness,
  );
}

final _pureBlackSurface = Color.lerp(
  Colors.grey.shade900,
  Colors.black,
  0.8,
);

enum EmoticThemeMode {
  system,
  light,
  dark,
  black;

  ThemeMode toThemeMode() {
    return switch (this) {
      EmoticThemeMode.system => ThemeMode.system,
      EmoticThemeMode.light => ThemeMode.light,
      EmoticThemeMode.dark || EmoticThemeMode.black => ThemeMode.dark,
    };
  }

  bool get isPureBlack {
    return this == EmoticThemeMode.black ? true : false;
  }
}
