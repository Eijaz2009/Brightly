import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_style.dart';

/// A single scholarship row used across Home / Explore / Saved.
///
/// IMPORTANT: [heroPrefix] MUST be unique per surface. Multiple `Hero` widgets
/// sharing a tag inside one `Navigator` route (e.g. inside an `IndexedStack`)
/// throws at runtime. Each list passes its own prefix.
class ScholarshipCard extends StatelessWidget {
  final Map<String, dynamic> scholarship;
  final bool isBookmarked;
  final VoidCallback? onTap;
  final VoidCallback onBookmarkTap;
  final String heroPrefix;

  const ScholarshipCard({
    super.key,
    required this.scholarship,
    required this.isBookmarked,
    required this.onBookmarkTap,
    this.onTap,
    this.heroPrefix = 'scholarship',
  });

  // ── Safe accessors, usable without instantiating the widget ──
  static String titleOf(Map<String, dynamic> s) {
    final raw = s['title']?.toString().trim();
    return (raw == null || raw.isEmpty) ? 'Untitled Scholarship' : raw;
  }

  static String countryOf(Map<String, dynamic> s) {
    final raw = s['country']?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    final subtitle = s['subtitle']?.toString() ?? '';
    if (subtitle.contains('·')) {
      final tail = subtitle.split('·').last.trim();
      if (tail.isNotEmpty) return tail;
    }
    return subtitle.isEmpty ? 'Global' : subtitle;
  }

  static String subtitleOf(Map<String, dynamic> s) {
    final raw = s['subtitle']?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    final c = countryOf(s);
    return c == 'Global' ? 'Scholarship' : c;
  }

  static String levelOf(Map<String, dynamic> s) =>
      s['level']?.toString().trim() ?? 'N/A';

  static String fundingOf(Map<String, dynamic> s) =>
      s['funding']?.toString().trim() ?? 'N/A';

  static String deadlineOf(Map<String, dynamic> s) {
    final raw = s['deadline']?.toString().trim();
    if (raw == null || raw.isEmpty) return 'Varies';
    return raw;
  }

  static String urlOf(Map<String, dynamic> s) {
    final raw = s['url']?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(titleOf(s))}';
  }

  static String flagOf(Map<String, dynamic> s) =>
      s['flag']?.toString().trim() ?? '🌍';

  String get title => titleOf(scholarship);
  String get country => countryOf(scholarship);
  String get subtitle => subtitleOf(scholarship);
  String get level => levelOf(scholarship);
  String get funding => fundingOf(scholarship);
  String get deadline => deadlineOf(scholarship);
  String get url => urlOf(scholarship);
  String get flag => flagOf(scholarship);
  String get heroTag => '$heroPrefix::$title';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppStyle.rLg),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppStyle.getCardColor(context),
            borderRadius: BorderRadius.circular(AppStyle.rLg),
            border: Border.all(color: AppStyle.getBorderColor(context), width: 1),
          ),
          child: Row(
            children: [
              Hero(
                tag: heroTag,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppStyle.getSandColor(context),
                    borderRadius: BorderRadius.circular(AppStyle.rMd),
                  ),
                  alignment: Alignment.center,
                  child: Text(flag, style: const TextStyle(fontSize: 26)),
                ),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        height: 1.25,
                        color: AppStyle.getTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 12,
                          color: AppStyle.getSubtitleColor(context),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            country,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppStyle.getSubtitleColor(context),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    // Level + funding chips must never push the row wider
                    // than the card, so they clip instead of overflowing.
                    ClipRect(
                      child: Row(
                        children: [
                          Flexible(
                            child: AppStyle.chip(
                              context,
                              label: level,
                              color: AppStyle.ink,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: AppStyle.chip(
                              context,
                              label: funding,
                              color: AppStyle.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _BookmarkButton(
                isBookmarked: isBookmarked,
                onTap: onBookmarkTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  final bool isBookmarked;
  final VoidCallback onTap;

  const _BookmarkButton({required this.isBookmarked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Saved state uses the brand blue, matching the nav bar's active colour so
    // "bookmarked" and "current tab" read as the same kind of signal.
    final color = isBookmarked
        ? AppStyle.spark
        : AppStyle.getSubtitleColor(context);

    return Semantics(
      button: true,
      selected: isBookmarked,
      label: isBookmarked ? 'Hapus dari tersimpan' : 'Simpan beasiswa',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isBookmarked
                  ? AppStyle.coral.withValues(alpha: 0.12)
                  : AppStyle.getSandColor(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  key: ValueKey(isBookmarked),
                  color: color,
                  size: 19,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
