import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

/// Persistent bottom navigation for detail screens
/// This widget mirrors the main AnimatedBottomNavBar for consistency
class DetailBottomNavBar extends StatelessWidget {
  const DetailBottomNavBar({super.key});

  static const List<_NavItem> _items = [
    _NavItem(Icons.home_outlined, Icons.home, 'Home', 0),
    _NavItem(Icons.menu_book_outlined, Icons.menu_book, 'Manga', 1),
    _NavItem(Icons.visibility_outlined, Icons.visibility, 'In Visione', 2),
    _NavItem(Icons.history_outlined, Icons.history, 'Cronologia', 3),
    _NavItem(Icons.video_library_outlined, Icons.video_library, 'Libreria', 4),
    _NavItem(Icons.smart_toy_outlined, Icons.smart_toy, 'AI', 5),
    _NavItem(Icons.person_outline, Icons.person, 'Profilo', 6),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / _items.length;
    final showLabels = itemWidth > 50;

    return Container(
      height: showLabels ? 60 : 50,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _items.map((item) {
            return Expanded(
              child: InkWell(
                onTap: () => _navigateToTab(context, item.tabIndex),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      size: showLabels ? 22 : 24,
                      color: AppTheme.textMuted,
                    ),
                    if (showLabels) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _navigateToTab(BuildContext context, int tabIndex) {
    // Navigate to home with query parameter for tab selection
    switch (tabIndex) {
      case 2:
        context.go('/watching');
        break;
      case 3:
        context.go('/history');
        break;
      default:
        // For other tabs, go to home and let MainNavigationScreen handle tab selection
        // Using extra to pass tab index
        context.go('/home');
        break;
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int tabIndex;

  const _NavItem(this.icon, this.activeIcon, this.label, this.tabIndex);
}
