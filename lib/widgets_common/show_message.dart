import 'package:flutter/material.dart';

void showSnackBar(BuildContext context, {required String text}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text)),
  );
}

void showAlertDialog(
  BuildContext context, {
  required String title,
  required String content,
  required VoidCallback onPressed,
}) {
  // showDialog
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onPressed();
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
