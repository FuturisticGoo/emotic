import 'package:flutter/material.dart';

void showSnackBar(
  BuildContext context, {
  required String text,
  Duration duration = const Duration(milliseconds: 500),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      duration: duration,
    ),
  );
}
