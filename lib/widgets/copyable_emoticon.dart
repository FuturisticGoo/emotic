import 'package:emotic/core/emoticon.dart';
import 'package:emotic/widgets/show_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyableEmoticon extends StatefulWidget {
  final Emoticon emoticon;
  final Function(Emoticon) onLongPressed;
  const CopyableEmoticon({
    super.key,
    required this.emoticon,
    required this.onLongPressed,
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
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: widget.emoticon.text));
          if (context.mounted) {
            showSnackBar(context, text: "Copied ${widget.emoticon.text}");
          }
        },
        onLongPress: () {
          widget.onLongPressed(widget.emoticon);
        },
        onSecondaryTap: () {
          widget.onLongPressed(widget.emoticon);
          // onLongPress(emoticon);
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(widget.emoticon.text),
        ),
      ),
    );
  }
}
