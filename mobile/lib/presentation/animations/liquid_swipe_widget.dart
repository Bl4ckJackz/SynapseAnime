import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';

class LiquidSwipeWidget extends StatelessWidget {
  final List<Widget> pages;
  final int initialPage;
  final Color? backgroundColor;
  final bool fullSlide;
  final Duration slideFactor;

  const LiquidSwipeWidget({
    super.key,
    required this.pages,
    this.initialPage = 0,
    this.backgroundColor,
    this.fullSlide = true,
    this.slideFactor = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return LiquidSwipe(
      pages: pages,
      initialPage: initialPage,
      liquidController: LiquidController(),
      onPageChangeCallback: (page) {},
      currentUpdateTypeCallback: (updateType) {},
      waveType: WaveType.liquidReveal,
    );
  }
}

// Example liquid swipe page
class LiquidSwipePage extends StatelessWidget {
  final String title;
  final String description;
  final Color backgroundColor;
  final IconData icon;

  const LiquidSwipePage({
    super.key,
    required this.title,
    required this.description,
    required this.backgroundColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            const SizedBox(height: 20),
            Center(
              child: Icon(
                icon,
                size: 100,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontFamily: 'Billy',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'Billy',
                fontWeight: FontWeight.w300,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
