import 'package:flutter/material.dart';

import '../../services/app_style.dart';

/// Row used in the admin scholarship lists.
class ScholarshipAdminCard extends StatelessWidget {
  final String flag;
  final String title;
  final String country;
  final String status;
  final String applications;
  final VoidCallback? onTap;

  const ScholarshipAdminCard({
    super.key,
    required this.flag,
    required this.title,
    required this.country,
    required this.status,
    required this.applications,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status.toLowerCase() == 'active';
    final statusColor = isActive ? AppStyle.mint : AppStyle.sunny;
    final dark = AppStyle.isDark(context);

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
              color: AppStyle.getBorderColor(context),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppStyle.ink.withValues(alpha: dark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(AppStyle.rSm),
                ),
                alignment: Alignment.center,
                child: Text(flag, style: const TextStyle(fontSize: 25)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.font(context, size: 14, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_rounded,
                          size: 12,
                          color: AppStyle.coral,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            country,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyle.font(
                              context,
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: AppStyle.getSubtitleColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppStyle.chip(
                    context,
                    label: status,
                    color: statusColor,
                    solid: true,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$applications pendaftar',
                    style: AppStyle.overline(context),
                  ),
                ],
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppStyle.getSubtitleColor(context),
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
