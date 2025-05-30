import 'package:flutter/material.dart';

class TagTile extends StatelessWidget {
  final String tag;
  final bool isSelected;
  final void Function() onTap;
  final Widget? trailing;
  const TagTile({
    super.key,
    required this.tag,
    required this.isSelected,
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
        title: Text(tag),
        onTap: onTap,
        trailing: trailing,
      ),
    );
  }
}
