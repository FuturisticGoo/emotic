import 'package:flutter/material.dart';

ThemeData getAppTheme({
  required ColorScheme? colorScheme,
  required Brightness brightness,
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
    colorScheme: colorScheme,
    brightness: brightness,
  );
}
