import 'package:emotic/core/emoticon.dart';
import 'package:flutter/material.dart';

class EmoticonTile extends StatelessWidget {
  final Emoticon emoticon;
  final bool isSelected;
  final void Function() onTap;
  const EmoticonTile({
    super.key,
    required this.isSelected,
    required this.emoticon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        selected: isSelected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
        title: Text(emoticon.text),
        onTap: onTap,
      ),
    );
  }
}
