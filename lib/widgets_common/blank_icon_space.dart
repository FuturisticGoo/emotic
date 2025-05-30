import 'package:flutter/material.dart';

class BlankIconSpace extends StatelessWidget {
  const BlankIconSpace({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Visibility.maintain(
      visible: false,
      child: Icon(Icons.abc),
    );
  }
}
