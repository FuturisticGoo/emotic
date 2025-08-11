import 'package:emotic/core/entities/emotic_image.dart';
import 'package:flutter/material.dart';

class EmotipicTile extends StatelessWidget {
  final EmoticImage image;
  final Widget? imageWidget;
  final bool isSelected;
  final void Function() onTap;
  final Widget? trailing;
  const EmotipicTile({
    super.key,
    required this.isSelected,
    required this.image,
    required this.imageWidget,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16).copyWith(
          right: trailing == null ? null : 8,
        ),
        selected: isSelected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
        title: imageWidget ??
            Center(
              child: CircularProgressIndicator(),
            ),
        onTap: onTap,
        trailing: trailing,
      ),
    );
  }
}
