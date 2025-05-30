import 'package:emotic/core/emotic_image.dart';
import 'package:flutter/material.dart';

class CopyableImage extends StatelessWidget {
  final Image imageWidget;
  final EmoticImage emoticImage;
  final void Function(EmoticImage emoticImage) onTap;
  final void Function(EmoticImage emoticImage) onSecondaryPress;
  const CopyableImage({
    super.key,
    required this.imageWidget,
    required this.emoticImage,
    required this.onTap,
    required this.onSecondaryPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: imageWidget,
      ),
      onTap: () => onTap(emoticImage),
      onLongPress: () => onSecondaryPress(emoticImage),
      onSecondaryTap: () => onSecondaryPress(emoticImage),
    );
  }
}
