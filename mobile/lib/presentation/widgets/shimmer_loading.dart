import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Clean Material Design shimmer loading for anime cards
class ShimmerAnimeCard extends StatefulWidget {
  final double width;
  final double height;

  const ShimmerAnimeCard({
    super.key,
    this.width = 140,
    this.height = 190,
  });

  @override
  State<ShimmerAnimeCard> createState() => _ShimmerAnimeCardState();
}

class _ShimmerAnimeCardState extends State<ShimmerAnimeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card placeholder
              Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.surfaceColor,
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment(-1 + _controller.value * 2, 0),
                      end: Alignment(_controller.value * 2, 0),
                      colors: [
                        AppTheme.surfaceColor,
                        AppTheme.surfaceColor.withValues(alpha: 0.7),
                        AppTheme.surfaceColor,
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Title placeholder
              Container(
                width: widget.width * 0.85,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: widget.width * 0.6,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              // Genre placeholder
              Container(
                width: widget.width * 0.4,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shimmer loading list
class ShimmerAnimeList extends StatelessWidget {
  final int itemCount;
  final double height;

  const ShimmerAnimeList({
    super.key,
    this.itemCount = 5,
    this.height = 320,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        itemBuilder: (context, index) => const ShimmerAnimeCard(),
      ),
    );
  }
}

/// Simple pulsing loading indicator
class PulsingDotIndicator extends StatefulWidget {
  final int dotCount;
  final double dotSize;
  final Color? color;

  const PulsingDotIndicator({
    super.key,
    this.dotCount = 3,
    this.dotSize = 8,
    this.color,
  });

  @override
  State<PulsingDotIndicator> createState() => _PulsingDotIndicatorState();
}

class _PulsingDotIndicatorState extends State<PulsingDotIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.dotCount, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final progress = (_controller.value + delay) % 1.0;
            final opacity = 0.3 + (0.7 * (1 - (progress - 0.5).abs() * 2));

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: widget.dotSize,
              height: widget.dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (widget.color ?? AppTheme.primaryColor)
                    .withValues(alpha: opacity),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Simple loading text
class GradientLoadingText extends StatelessWidget {
  final String text;
  final double fontSize;

  const GradientLoadingText({
    super.key,
    this.text = 'Caricamento...',
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        color: AppTheme.textMuted,
      ),
    );
  }
}
