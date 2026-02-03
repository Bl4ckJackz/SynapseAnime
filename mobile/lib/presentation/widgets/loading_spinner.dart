import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingSpinner extends StatelessWidget {
  final double size;
  final Color? color;

  const LoadingSpinner({
    super.key,
    this.size = 60.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/animations/rotation.json',
        fit: BoxFit.contain,
        // If the animation supports coloring, we could use delegates,
        // but often Lottie files have their own colors.
      ),
    );
  }
}
