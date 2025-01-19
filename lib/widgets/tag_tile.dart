import 'package:flutter/material.dart';

class TagTile extends StatelessWidget {
  final String tag;
  final bool isSelected;
  final void Function() onTap;
  const TagTile({
    super.key,
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        selected: isSelected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
        title: Text(tag),
        onTap: onTap,
      ),
    );
  }
}
