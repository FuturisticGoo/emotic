import 'package:flutter/material.dart';

class EmoticLogo extends StatelessWidget {
  const EmoticLogo({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "OwO",
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const Text("Emotic"),
        ],
      ),
    );
  }
}
