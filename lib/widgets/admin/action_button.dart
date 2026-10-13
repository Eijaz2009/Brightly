import 'package:flutter/material.dart';

import '../../services/app_style.dart';

/// Wide action row used in the admin dashboard's "Quick actions" section.
class AdminActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const AdminActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppStyle.isDark(context);
    final fg = color.computeLuminance() > 0.55 ? AppStyle.ink : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppStyle.rMd),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppStyle.getCardColor(context),
            borderRadius: BorderRadius.circular(AppStyle.rMd),
            border: Border.all(
              color: color.withValues(alpha: dark ? 0.26 : 0.16),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppStyle.rSm),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: fg, size: 19),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyle.font(context, size: 14, weight: FontWeight.w700),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppStyle.getSubtitleColor(context),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
