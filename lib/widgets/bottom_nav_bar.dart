// ============================================================
// bottom_nav_bar.dart
// ------------------------------------------------------------
// A reusable soft neumorphic bottom navigation bar shared by
// both Parent Dashboard and Child Dashboard. Each dashboard
// passes in its own list of icons/labels so the same widget
// can be reused for both modes.
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NavItem {
  final IconData icon;
  final String label;
  const NavItem({required this.icon, required this.label});
}

class AppBottomNavBar extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: AppDecorations.neumorphicCard(radius: 26),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final bool selected = index == currentIndex;
          final item = items[index];
          return GestureDetector(
            onTap: () => onTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: selected
                  ? AppDecorations.neumorphicInset(radius: 16)
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    color: selected ? AppColors.primaryDark : AppColors.textLight,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? AppColors.primaryDark : AppColors.textLight,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
