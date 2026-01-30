import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieAnimationWidget extends StatelessWidget {
  final String animationPath;
  final double width;
  final double height;
  final bool repeat;
  final bool reverse;

  const LottieAnimationWidget({
    Key? key,
    required this.animationPath,
    this.width = 200,
    this.height = 200,
    this.repeat = true,
    this.reverse = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      animationPath,
      width: width,
      height: height,
      repeat: repeat,
      reverse: reverse,
      fit: BoxFit.cover,
    );
  }
}

// Animated splash screen using Lottie
class SplashScreenLottie extends StatelessWidget {
  final String animationPath;
  final String title;
  final double logoSize;

  const SplashScreenLottie({
    Key? key,
    required this.animationPath,
    required this.title,
    this.logoSize = 150,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              animationPath,
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}