import 'dart:ui';
import 'package:flutter/material.dart';

class FrostedCard extends StatelessWidget {
  final Widget child;
  const FrostedCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Card.outlined(
          clipBehavior: Clip.hardEdge,
          color: Theme.of(context).cardColor.withValues(alpha: 0.1),
          child: child,
        ),
      ),
    );
  }
}
