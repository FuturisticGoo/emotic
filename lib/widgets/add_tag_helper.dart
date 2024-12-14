import 'package:flutter/material.dart';

Future<String?> addNewTag(BuildContext context) {
  return showAdaptiveDialog<String?>(
    context: context,
    builder: (context) {
      String newTagText = "";
      return SimpleDialog(
        title: const Text("Add new tag"),
        contentPadding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              label: Text("Tag"),
            ),
            onChanged: (value) {
              newTagText = value;
            },
          ),
          const SizedBox(
            height: 20,
          ),
          Builder(builder: (context) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                const SizedBox(
                  width: 10,
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      newTagText.trim().isEmpty ? null : newTagText.trim(),
                    );
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          })
        ],
      );
    },
  );
}
