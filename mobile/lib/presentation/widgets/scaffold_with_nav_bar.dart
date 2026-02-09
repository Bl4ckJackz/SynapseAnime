import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

/// Provider to track the current navigation index across shell routes
final shellNavIndexProvider = StateProvider<int>((ref) => 0);

/// Shell scaffold that provides persistent bottom navigation across all routes
class ScaffoldWithShellNav extends ConsumerWidget {
  final Widget child;

  const ScaffoldWithShellNav({super.key, required this.child});

  static const List<_ShellNavItem> _items = [
    _ShellNavItem(Icons.home_outlined, Icons.home, 'Home'),
    _ShellNavItem(Icons.menu_book_outlined, Icons.menu_book, 'Manga'),
    _ShellNavItem(Icons.visibility_outlined, Icons.visibility, 'In Visione'),
    _ShellNavItem(Icons.history_outlined, Icons.history, 'Cronologia'),
    _ShellNavItem(
        Icons.video_library_outlined, Icons.video_library, 'Libreria'),
    _ShellNavItem(Icons.smart_toy_outlined, Icons.smart_toy, 'AI'),
    _ShellNavItem(Icons.person_outline, Icons.person, 'Profilo'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(shellNavIndexProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / _items.length;
    final showLabels = itemWidth > 50;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
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
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isSelected = currentIndex == index;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    ref.read(shellNavIndexProvider.notifier).state = index;
                    context.go('/home?tab=$index');
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        size: 22,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.textMuted,
                      ),
                      if (showLabels) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
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

class _ShellNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _ShellNavItem(this.icon, this.activeIcon, this.label);
}
