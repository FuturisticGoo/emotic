import 'package:emotic/core/export_config.dart';
import 'package:flutter/material.dart';

Future<ExportConfig?> exportConfirmationDialog(BuildContext context) {
  return showAdaptiveDialog<ExportConfig?>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text("Export options"),
        contentPadding: const EdgeInsets.all(16.0),
        children: [
          const SizedBox(
            height: 20,
          ),
          ExportConfigWidget(),
        ],
      );
    },
  );
}

class ExportConfigWidget extends StatefulWidget {
  const ExportConfigWidget({
    super.key,
  });

  @override
  State<ExportConfigWidget> createState() => _ExportConfigWidgetState();
}

class _ExportConfigWidgetState extends State<ExportConfigWidget> {
  bool shouldExportEmoticons = true;
  bool shouldExportEmotipics = true;
  bool shouldExportSettings = true;
  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      return Column(
        children: [
          SwitchListTile(
            title: Text("Export all Emoticons"),
            value: shouldExportEmoticons,
            onChanged: (value) {
              setState(() {
                shouldExportEmoticons = value;
              });
            },
          ),
          SwitchListTile(
            title: Text("Export all Emotipics"),
            value: shouldExportEmotipics,
            onChanged: (value) {
              setState(() {
                shouldExportEmotipics = value;
              });
            },
          ),
          SwitchListTile(
            title: Text("Export settings"),
            value: shouldExportSettings,
            onChanged: (value) {
              setState(() {
                shouldExportSettings = value;
              });
            },
          ),
          const SizedBox(
            height: 20,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context, null);
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
                    ExportConfig(
                      shouldExportSettings: shouldExportSettings,
                      shouldExportEmoticons: shouldExportEmoticons,
                      shouldExportEmotipics: shouldExportEmotipics,
                    ),
                  );
                },
                child: const Text("Ok"),
              ),
            ],
          ),
        ],
      );
    });
  }
}
