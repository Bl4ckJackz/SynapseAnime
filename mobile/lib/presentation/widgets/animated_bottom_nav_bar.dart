import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';

class AnimatedBottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AnimatedBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      _buildNavItem(
        icon: Icons.home,
        label: 'Home',
        isSelected: currentIndex == 0,
        index: 0,
      ),
      _buildNavItem(
        icon: Icons.search,
        label: 'Cerca',
        isSelected: currentIndex == 1,
        index: 1,
      ),
      _buildNavItem(
        icon: Icons.menu_book,
        label: 'Manga',
        isSelected: currentIndex == 2,
        index: 2,
      ),
      _buildNavItem(
        icon: Icons.history,
        label: 'Cronologia',
        isSelected: currentIndex == 3,
        index: 3,
      ),
      _buildNavItem(
        icon: Icons.play_circle,
        label: 'Guarda',
        isSelected: currentIndex == 4,
        index: 4,
      ),
      _buildNavItem(
        icon: Icons.chat,
        label: 'AI',
        isSelected: currentIndex == 5,
        index: 5,
      ),
      _buildNavItem(
        icon: Icons.person,
        label: 'Profilo',
        isSelected: currentIndex == 6,
        index: 6,
      ),
    ];

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    int? index, // Add index parameter
  }) {
    return GestureDetector(
      onTap: () => onTap(index ?? 0), // Use the provided index
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
