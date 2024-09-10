import 'package:emotic/core/emoticon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyableEmoticon extends StatelessWidget {
  final Emoticon emoticon;
  final Function(Emoticon) onLongPress;
  const CopyableEmoticon({
    super.key,
    required this.emoticon,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: emoticon.text));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied ${emoticon.text}'),
                duration: const Duration(milliseconds: 500),
              ),
            );
          }
        },
        onLongPress: () {
          onLongPress(emoticon);
        },
        onSecondaryTap: () {
          onLongPress(emoticon);
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(emoticon.text),
        ),
      ),
    );
  }
}
