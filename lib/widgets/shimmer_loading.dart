import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../services/app_style.dart';

/// Skeleton card shown while the catalogue loads.
class ShimmerLoadingCard extends StatelessWidget {
  const ShimmerLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = AppStyle.isDark(context);
    final baseColor = AppStyle.getCardColor(context);
    final highlight = dark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.9);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1400),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(AppStyle.rMd),
          border: Border.all(color: AppStyle.getBorderColor(context), width: 1.4),
        ),
        child: const Row(
          children: [
            _Block(width: 54, height: 54, radius: AppStyle.rSm),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Block(width: double.infinity, height: 14, radius: 7),
                  SizedBox(height: 9),
                  _Block(width: 110, height: 11, radius: 6),
                  SizedBox(height: 9),
                  _Block(width: 150, height: 18, radius: 8),
                ],
              ),
            ),
            SizedBox(width: 10),
            _Block(width: 38, height: 38, radius: 19),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _Block({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
