import 'package:emotic/core/emoticon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyableEmoticon extends StatefulWidget {
  final Emoticon emoticon;
  final Function(Emoticon) onEditPressed;
  final Function(Emoticon) onDeletePressed;
  const CopyableEmoticon({
    super.key,
    required this.emoticon,
    required this.onEditPressed,
    required this.onDeletePressed,
  });

  @override
  State<CopyableEmoticon> createState() => _CopyableEmoticonState();
}

class _CopyableEmoticonState extends State<CopyableEmoticon> {
  final MenuController menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      clipBehavior: Clip.hardEdge,
      child: MenuAnchor(
        controller: menuController,
        builder: (context, controller, child) {
          return InkWell(
            onTap: () async {
              await Clipboard.setData(
                  ClipboardData(text: widget.emoticon.text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied ${widget.emoticon.text}'),
                    duration: const Duration(milliseconds: 500),
                  ),
                );
              }
            },
            onLongPress: () {
              menuController.open();
            },
            onSecondaryTap: () {
              menuController.open();
              // onLongPress(emoticon);
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(widget.emoticon.text),
            ),
          );
        },
        menuChildren: [
          MenuItemButton(
            onPressed: () async {
              widget.onEditPressed(widget.emoticon);
            },
            child: const Row(
              children: [
                Icon(Icons.edit),
                SizedBox(
                  width: 5,
                ),
                Text("Edit"),
              ],
            ),
          ),
          MenuItemButton(
            onPressed: () async {
              final shouldDelete = await confirmDeletionDialog(context);
              if (shouldDelete == true) {
                widget.onDeletePressed(widget.emoticon);
              }
            },
            child: const Row(
              children: [
                Icon(Icons.delete),
                SizedBox(
                  width: 5,
                ),
                Text("Delete"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> confirmDeletionDialog(BuildContext context) {
    return showAdaptiveDialog<bool?>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("Confirm deletion"),
          contentPadding: const EdgeInsets.all(8.0),
          children: [
            Builder(builder: (context) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    child: const Text("No"),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        true,
                      );
                    },
                    child: const Text("Yes"),
                  ),
                ],
              );
            })
          ],
        );
      },
    );
  }
}
