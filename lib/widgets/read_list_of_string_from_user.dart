import 'package:flutter/material.dart';

Future<List<String>?> readListOfStringFromUser(
  BuildContext context, {
  required String titleText,
  required String textLabel,
  String textHint = "Type one per line",
  String positiveButtonText = "Add",
}) {
  return showAdaptiveDialog<List<String>?>(
    context: context,
    builder: (context) {
      String newTagsText = "";
      return SimpleDialog(
        title: Text(titleText),
        contentPadding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            maxLines: null,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              label: Text(textLabel),
              hintText: textHint,
            ),
            onChanged: (value) {
              newTagsText = value;
            },
          ),
          const SizedBox(
            height: 20,
          ),
          Builder(
            builder: (context) {
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
                        newTagsText.trim().isEmpty
                            ? null
                            : newTagsText
                                .split("\n")
                                .where(
                                  (element) => element.trim().isNotEmpty,
                                )
                                .toList(),
                      );
                    },
                    child: Text(positiveButtonText),
                  ),
                ],
              );
            },
          )
        ],
      );
    },
  );
}

Future<List<String>?> readTags(BuildContext context) async {
  return readListOfStringFromUser(
    context,
    titleText: "Add new tags",
    textLabel: "Tags",
    textHint: "Type one tag per line",
  );
}
