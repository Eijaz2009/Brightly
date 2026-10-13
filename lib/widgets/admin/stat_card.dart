import 'package:flutter/material.dart';

import '../../services/app_style.dart';

/// Compact stat tile for the admin dashboard.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String number;
  final String label;
  final Color color;

  const StatCard({
    super.key,
    required this.icon,
    required this.number,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppStyle.isDark(context);
    final fg = color.computeLuminance() > 0.55 ? AppStyle.ink : Colors.white;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppStyle.getCardColor(context),
        borderRadius: BorderRadius.circular(AppStyle.rMd),
        border: Border.all(color: AppStyle.getBorderColor(context), width: 1.4),
        boxShadow: AppStyle.softShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: dark ? 0.24 : 1),
              borderRadius: BorderRadius.circular(AppStyle.rSm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyle.numeral(context, size: 21),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyle.overline(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
