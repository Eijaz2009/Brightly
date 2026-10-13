import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/scholarship_provider.dart';
import '../services/app_style.dart';
import '../services/app_translations.dart';

class DetailScreen extends StatefulWidget {
  final String flag;
  final String title;
  final String country;
  final String level;
  final String funding;
  final String deadline;
  final String officialUrl;
  final bool isBookmarked;
  final VoidCallback? onBookmarkTap;

  /// Must match the tag used by the source list, otherwise the Hero
  /// animation silently degrades.
  final String? heroTag;

  const DetailScreen({
    super.key,
    required this.flag,
    required this.title,
    required this.country,
    required this.level,
    required this.funding,
    required this.deadline,
    required this.officialUrl,
    required this.isBookmarked,
    this.onBookmarkTap,
    this.heroTag,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  String get flag => widget.flag;
  String get title => widget.title;
  String get country => widget.country;
  String get level => widget.level;
  String get funding => widget.funding;
  String get deadline => widget.deadline;
  String get officialUrl => widget.officialUrl;

  Future<void> _launchUrl() async {
    final uri = Uri.tryParse(officialUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _toast('Tautan tidak valid.', AppStyle.danger);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Tidak bisa membuka situs'),
        backgroundColor: AppStyle.danger,
      ),
    );
  }

  Future<void> _share() async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '🎓 Cek beasiswa ini!\n\n$title\n$country\n'
            'Jenjang: $level\nPendanaan: $funding\nDeadline: $deadline\n\n'
            '🔗 $officialUrl',
      ),
    );
    if (!mounted) return;
    _toast('Info beasiswa disalin. Bagikan ke temanmu! 🚀', AppStyle.mint);
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: AppStyle.background(
        context: context,
        child: Column(
          children: [
            AppHeaders.pageHeader(
              context: context,
              title: 'Detail Beasiswa',
              subtitle: country,
              leading: AppStyle.circleButton(
                context: context,
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
                size: 42,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppStyle.circleButton(
                    context: context,
                    icon: Icons.ios_share_rounded,
                    size: 40,
                    iconSize: 17,
                    onTap: _share,
                  ),
                  const SizedBox(width: 8),
                  Consumer<ScholarshipProvider>(
                    builder: (context, p, _) => AppStyle.circleButton(
                      context: context,
                      icon: p.isBookmarked(title)
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 40,
                      iconSize: 17,
                      iconColor: p.isBookmarked(title)
                          ? AppStyle.spark
                          : null,
                      background: p.isBookmarked(title)
                          ? AppStyle.spark.withValues(alpha: 0.10)
                          : null,
                      onTap: () {
                        if (widget.onBookmarkTap != null) {
                          widget.onBookmarkTap!();
                        } else {
                          p.toggleBookmark(title);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  AppStyle.bottomInset(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Hero(
                      flag: flag,
                      country: country,
                      title: title,
                      heroTag: widget.heroTag ?? 'detail::$title',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _InfoTile(
                          icon: Icons.school_rounded,
                          label: 'Jenjang',
                          value: level,
                          color: AppStyle.spark,
                        ),
                        const SizedBox(width: 10),
                        _InfoTile(
                          icon: Icons.payments_rounded,
                          label: 'Pendanaan',
                          value: funding,
                          color: AppStyle.spark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DeadlineCard(deadline: deadline),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Tentang beasiswa',
                      accent: AppStyle.spark,
                      child: Text(
                        AppTranslations.get('about_scholarship_desc'),
                        style: AppStyle.font(
                          context,
                          size: 13.5,
                          weight: FontWeight.w500,
                          height: 1.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Section(
                      title: 'Persyaratan',
                      accent: AppStyle.success,
                      child: Column(
                        children: [
                          for (final item in [
                            AppTranslations.get('req_1'),
                            AppTranslations.get('req_2'),
                            AppTranslations.get('req_3'),
                            AppTranslations.get('req_4'),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppStyle.success,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: AppStyle.font(
                                        context,
                                        size: 12.5,
                                        weight: FontWeight.w500,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppStyle.primaryButton(
                      context: context,
                      label: AppTranslations.get('visit_website'),
                      icon: Icons.open_in_new_rounded,
                      color: AppStyle.ink,
                      onPressed: _launchUrl,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════

class _Hero extends StatelessWidget {
  final String flag;
  final String country;
  final String title;
  final String heroTag;

  const _Hero({
    required this.flag,
    required this.country,
    required this.title,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppStyle.ink;
    final fg = color.computeLuminance() > 0.55 ? AppStyle.ink : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppStyle.gradientOf(color),
        borderRadius: BorderRadius.circular(AppStyle.rXl),
        boxShadow: AppStyle.liftShadow(context, tint: color),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -6,
            right: -2,
            child: IgnorePointer(
              child: AppStyle.sparkles(size: 16, color: fg, count: 2),
            ),
          ),
          Row(
            children: [
              Hero(
                tag: heroTag,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppStyle.rMd),
                  ),
                  alignment: Alignment.center,
                  child: Text(flag, style: const TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place_rounded, size: 13, color: fg),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            country,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: fg.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: fg,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.22,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppStyle.isDark(context) ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(AppStyle.rMd),
          border: Border.all(
            color: color.withValues(alpha: AppStyle.isDark(context) ? 0.26 : 0.16),
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppStyle.font(context, size: 13, weight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 3),
            Text(label.toUpperCase(), style: AppStyle.overline(context)),
          ],
        ),
      ),
    );
  }
}

class _DeadlineCard extends StatelessWidget {
  final String deadline;

  const _DeadlineCard({required this.deadline});

  /// Days remaining until the end of the deadline month, or null when the
  /// value cannot be parsed ("Varies").
  static int? daysRemaining(String raw) {
    final parsed = _tryParse(raw);
    if (parsed == null) return null;
    final now = DateTime.now();
    return parsed.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  static DateTime? _tryParse(String raw) {
    const months = <String, int>{
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };

    int? day;
    int? month;
    int? year;

    for (final token in raw.trim().split(RegExp(r'[\s/.-]+'))) {
      if (token.isEmpty) continue;
      final asNum = int.tryParse(token);
      if (asNum != null && token.length == 4) {
        year = asNum;
      } else if (asNum != null) {
        day ??= asNum;
      } else if (token.length >= 3) {
        month ??= months[token.substring(0, 3)];
      }
    }

    if (month == null || year == null) return null;
    final d = day ?? 1;
    if (d < 1 || d > 31) return null;

    // `MMM yyyy` means "end of that month".
    if (day == null) return DateTime(year, month + 1, 0);
    return DateTime(year, month, d);
  }

  @override
  Widget build(BuildContext context) {
    final days = daysRemaining(deadline);

    late final Color color;
    late final IconData icon;
    late final String badge;

    if (days == null) {
      color = AppStyle.secondarySlate;
      icon = Icons.event_repeat_rounded;
      badge = 'Berbeda-beda';
    } else if (days < 0) {
      color = AppStyle.danger;
      icon = Icons.event_busy_rounded;
      badge = 'Ditutup';
    } else if (days <= 30) {
      // Urgency is the one place a second colour earns its keep: the user needs
      // to tell "closing soon" from "plenty of time" at a glance.
      color = days <= 7 ? AppStyle.danger : AppStyle.warning;
      icon = Icons.timer_rounded;
      badge = days == 0 ? 'Hari terakhir!' : '$days hari lagi';
    } else {
      color = AppStyle.success;
      icon = Icons.event_available_rounded;
      badge = '$days hari lagi';
    }

    final onLight = color.computeLuminance() > 0.55;
    final badgeText = days != null && days > 45 ? '$days hari' : badge;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppStyle.isDark(context) ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(AppStyle.rLg),
        border: Border.all(
          color: color.withValues(alpha: AppStyle.isDark(context) ? 0.26 : 0.18),
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: onLight ? 0.18 : 0.2),
              borderRadius: BorderRadius.circular(AppStyle.rSm),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: onLight ? AppStyle.ink : Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('DEADLINE', style: AppStyle.overline(context, color: color)),
                const SizedBox(height: 3),
                Text(
                  deadline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyle.font(context, size: 14, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Flexible badge: a long deadline string plus a fixed badge used to
          // overflow narrow screens.
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppStyle.rPill),
              ),
              child: Text(
                badgeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: onLight ? AppStyle.ink : Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Color accent;
  final Widget child;

  const _Section({
    required this.title,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppStyle.getCardColor(context),
        borderRadius: BorderRadius.circular(AppStyle.rLg),
        border: Border.all(color: AppStyle.getBorderColor(context), width: 1.4),
        boxShadow: AppStyle.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: accent.computeLuminance() > 0.55
                      ? AppStyle.ink
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyle.font(context, size: 14.5, weight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}
