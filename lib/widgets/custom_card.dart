// ============================================================
// custom_card.dart
// ------------------------------------------------------------
// A reusable soft neumorphic card. Used for dashboard tiles,
// info panels, and list items throughout the app.
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const CustomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: AppDecorations.neumorphicCard(),
        child: child,
      ),
    );
  }
}

// --------------------------------------------------------
// A smaller variant used for dashboard "stat" tiles, e.g.
// Battery, Last Seen, Distance, SOS Status.
// --------------------------------------------------------
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 10),
          Text(value, style: AppTextStyles.heading.copyWith(fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.subheading.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
