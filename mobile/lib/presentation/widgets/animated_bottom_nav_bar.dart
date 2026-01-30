import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Bottom navigation with wave effect rising from active icon
class AnimatedBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AnimatedBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AnimatedBottomNavBar> createState() => _AnimatedBottomNavBarState();
}

class _AnimatedBottomNavBarState extends State<AnimatedBottomNavBar>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  static const List<NavItem> _items = [
    NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    NavItem(
        icon: Icons.search_outlined, activeIcon: Icons.search, label: 'Cerca'),
    NavItem(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        label: 'Manga'),
    NavItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: 'Cronologia'),
    NavItem(
        icon: Icons.smart_toy_outlined,
        activeIcon: Icons.smart_toy,
        label: 'AI'),
    NavItem(
        icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profilo'),
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _waveAnimation = CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeOutQuart,
    );
    _waveController.forward();
  }

  @override
  void didUpdateWidget(AnimatedBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _waveController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRect(
        child: CustomPaint(
          painter: _WavePainter(
            animation: _waveAnimation,
            selectedIndex: widget.currentIndex,
            itemCount: _items.length,
            waveColor: AppTheme.primaryColor.withValues(alpha: 0.12),
          ),
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isSelected = widget.currentIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: _NavItemWidget(
                    item: item,
                    isSelected: isSelected,
                    animation: _waveAnimation,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Animation<double> animation;
  final int selectedIndex;
  final int itemCount;
  final Color waveColor;

  _WavePainter({
    required this.animation,
    required this.selectedIndex,
    required this.itemCount,
    required this.waveColor,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.fill;

    final itemWidth = size.width / itemCount;
    final centerX = itemWidth * selectedIndex + itemWidth / 2;

    // Animated wave radius
    final maxRadius = size.width * 0.4;
    final radius = maxRadius * animation.value;

    // Draw expanding wave circles
    for (int i = 0; i < 3; i++) {
      final waveRadius = radius * (1 - i * 0.2);
      final opacity = (1 - animation.value) * (1 - i * 0.3);

      if (waveRadius > 0 && opacity > 0) {
        paint.color = waveColor.withValues(alpha: opacity * 0.15);
        canvas.drawCircle(
          Offset(centerX, size.height),
          waveRadius,
          paint,
        );
      }
    }

    // Static glow under selected item
    final glowPaint = Paint()
      ..color = waveColor.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawCircle(
      Offset(centerX, size.height + 10),
      40,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex;
}

class _NavItemWidget extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final Animation<double> animation;

  const _NavItemWidget({
    required this.item,
    required this.isSelected,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Bounce up effect for selected item
        final bounce =
            isSelected ? math.sin(animation.value * math.pi) * 4 : 0.0;

        return Transform.translate(
          offset: Offset(0, -bounce),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  size: 24,
                  color:
                      isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color:
                      isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
