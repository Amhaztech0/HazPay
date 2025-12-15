import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chat_bubble_rounded,
      size: size,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}
