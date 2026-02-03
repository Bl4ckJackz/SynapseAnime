import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AppLoader extends StatefulWidget {
  final double? width;
  final double? height;

  const AppLoader({super.key, this.width, this.height});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  late String _currentAnimation;
  final List<String> _animations = [
    'assets/animations/rotation.json',
  ];

  @override
  void initState() {
    super.initState();
    // Pick a random animation (list only has one now)
    _currentAnimation = _animations[0];
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        _currentAnimation,
        width: widget.width ?? 100,
        height: widget.height ?? 100,
        errorBuilder: (context, error, stackTrace) {
          return const CircularProgressIndicator();
        },
      ),
    );
  }
}
