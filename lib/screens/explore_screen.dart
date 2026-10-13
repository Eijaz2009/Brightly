import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/scholarship_provider.dart';
import '../services/app_style.dart';
import '../services/app_translations.dart';
import '../widgets/scholarship_card.dart';
import 'detail_screen.dart';
import 'quiz_screen.dart';

const String _helpWhatsapp =
    'https://wa.me/6281297446236?text=${'Halo%20Brightly%2C%20saya%20butuh%20bantuan%20memilih%20beasiswa%20yang%20tepat.'}';

class _Category {
  final String id;
  final String labelKey;
  final IconData icon;
  final Color color;

  const _Category({
    required this.id,
    required this.labelKey,
    required this.icon,
    required this.color,
  });
}

const List<_Category> _kCategories = <_Category>[
  _Category(
    id: 'S1',
    labelKey: 'undergraduate',
    icon: Icons.school_rounded,
    color: AppStyle.ink,
  ),
  _Category(
    id: 'S2',
    labelKey: 'postgraduate',
    icon: Icons.workspace_premium_rounded,
    color: AppStyle.spark,
  ),
  _Category(
    id: 'S3',
    labelKey: 'phd_programs',
    icon: Icons.auto_stories_rounded,
    color: AppStyle.spark,
  ),
  _Category(
    id: 'full',
    labelKey: 'full_funding',
    icon: Icons.payments_rounded,
    color: AppStyle.success,
  ),
];

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const String _heroPrefix = 'explore';

  final _searchController = TextEditingController();
  String _query = '';

  /// Stored as a stable id, never as translated text — otherwise switching
  /// language while a category is open used to throw in `firstWhere`.
  String? _selectedId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _countFor(String id, List<Map<String, dynamic>> all) {
    switch (id) {
      case 'S1':
      case 'S2':
      case 'S3':
        return all
            .where(
              (s) =>
                  ScholarshipCard.levelOf(s).toUpperCase().contains(id),
            )
            .length;
      case 'full':
        return all
            .where(
              (s) => ScholarshipCard.fundingOf(
                s,
              ).toLowerCase().contains('full'),
            )
            .length;
      default:
        return 0;
    }
  }

  List<Map<String, dynamic>> _filterByCategory(
    List<Map<String, dynamic>> all,
    String id,
  ) {
    switch (id) {
      case 'S1':
      case 'S2':
      case 'S3':
        return all
            .where(
              (s) => ScholarshipCard.levelOf(s).toUpperCase().contains(id),
            )
            .toList(growable: false);
      case 'full':
        return all
            .where(
              (s) => ScholarshipCard.fundingOf(s).toLowerCase().contains('full'),
            )
            .toList(growable: false);
      default:
        return const [];
    }
  }

  _Category? get _selected =>
      _kCategories.where((c) => c.id == _selectedId).firstOrNull;

  void _openDetail(Map<String, dynamic> data) {
    final provider = context.read<ScholarshipProvider>();
    final title = ScholarshipCard.titleOf(data);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          flag: ScholarshipCard.flagOf(data),
          title: title,
          country: ScholarshipCard.countryOf(data),
          level: ScholarshipCard.levelOf(data),
          funding: ScholarshipCard.fundingOf(data),
          deadline: ScholarshipCard.deadlineOf(data),
          officialUrl: ScholarshipCard.urlOf(data),
          isBookmarked: provider.isBookmarked(title),
          heroTag: '$_heroPrefix::$title',
          onBookmarkTap: () => provider.toggleBookmark(title),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScholarshipProvider>();
    final all = provider.scholarships;
    final query = _query.trim().toLowerCase();

    final results = query.isNotEmpty
        ? provider.filteredScholarships
        : (_selectedId != null
              ? _filterByCategory(all, _selectedId!)
              : all);

    final isBrowsing = query.isNotEmpty || _selectedId != null;

    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: AppStyle.background(
        context: context,
        child: Column(
          children: [
            AppHeaders.pageHeader(
              context: context,
              title: 'Jelajahi',
              subtitle: '${all.length} beasiswa tersedia',
              showSearch: true,
              searchController: _searchController,
              onSearchChanged: (v) => setState(() => _query = v),
              onSearchCleared: () => setState(() => _query = ''),
              searchHint: AppTranslations.get('search_scholarships'),
            ),
            Expanded(
              child: isBrowsing
                  ? _buildResults(context, provider, results, query)
                  : _buildCategories(context, provider, all),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── categories ─────────────────────────
  Widget _buildCategories(
    BuildContext context,
    ScholarshipProvider provider,
    List<Map<String, dynamic>> all,
  ) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        AppStyle.bottomInset(context) + 84,
      ),
      children: [
        // ── "What are you after?" banner ──
        _QuizBanner(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScholarshipQuizScreen(
                scholarships: provider.scholarships,
                onToggleBookmark: provider.toggleBookmark,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        AppStyle.sectionTitle(
          context,
          title: 'Telusuri kategori',
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _kCategories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.02,
          ),
          itemBuilder: (context, index) {
            final cat = _kCategories[index];
            return _CategoryTile(
              category: cat,
              count: _countFor(cat.id, all),
              onTap: () => setState(() => _selectedId = cat.id),
            );
          },
        ),
        const SizedBox(height: 16),
        _HelpBanner(onTap: () => _openWhatsApp(context)),
      ],
    );
  }

  // ───────────────────────── results ─────────────────────────
  Widget _buildResults(
    BuildContext context,
    ScholarshipProvider provider,
    List<Map<String, dynamic>> results,
    String query,
  ) {
    final selected = _selected;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Row(
            children: [
              if (selected != null && query.isEmpty)
                AppStyle.circleButton(
                  context: context,
                  icon: Icons.arrow_back_rounded,
                  size: 38,
                  iconSize: 17,
                  onTap: () => setState(() => _selectedId = null),
                ),
              if (selected != null && query.isEmpty) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected != null && query.isEmpty
                      ? AppTranslations.get(selected.labelKey)
                      : 'Hasil pencarian',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyle.font(context, size: 17, weight: FontWeight.w800),
                ),
              ),
              if (selected != null && query.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppStyle.rPill),
                  ),
                  child: Text(
                    '${results.length}',
                    style: AppStyle.font(
                      context,
                      size: 13,
                      weight: FontWeight.w800,
                      color: selected.color,
                    ),
                  ),
                )
              else
                Text(
                  '${results.length} ditemukan',
                  style: AppStyle.font(
                    context,
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppStyle.getSubtitleColor(context),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : results.isEmpty
              ? AppStyle.emptyState(
                  context: context,
                  icon: Icons.search_off_rounded,
                  title: query.isEmpty
                      ? AppTranslations.get('no_category_results')
                      : 'Tidak ada hasil untuk "$query"',
                  subtitle: 'Coba kata kunci atau kategori lain.',
                  color: selected?.color ?? AppStyle.periwinkle,
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      AppStyle.bottomInset(context) + 84,
                    ),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final s = results[index];
                    final title = ScholarshipCard.titleOf(s);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ScholarshipCard(
                        scholarship: s,
                        heroPrefix: _heroPrefix,
                        isBookmarked: provider.isBookmarked(title),
                        onBookmarkTap: () => provider.toggleBookmark(title),
                        onTap: () => _openDetail(s),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse(_helpWhatsapp);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tidak bisa membuka WhatsApp')),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════════

class _CategoryTile extends StatelessWidget {
  final _Category category;
  final int count;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppStyle.isDark(context);
    final color = category.color;
    final fg = color.computeLuminance() > 0.55 ? AppStyle.ink : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppStyle.rLg),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppStyle.getCardColor(context),
            borderRadius: BorderRadius.circular(AppStyle.rLg),
            border: Border.all(
              color: AppStyle.getBorderColor(context),
              width: 1.4,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: dark ? 0.24 : 1),
                  borderRadius: BorderRadius.circular(AppStyle.rSm),
                ),
                alignment: Alignment.center,
                child: Icon(category.icon, color: fg, size: 22),
              ),
              const Spacer(),
              Text(
                AppTranslations.get(category.labelKey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppStyle.font(
                  context,
                  size: 14,
                  weight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '$count',
                    style: AppStyle.numeral(context, size: 15, color: color),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      AppTranslations.get('available'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.overline(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _QuizBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _InfoBanner(
      onTap: onTap,
      color: AppStyle.spark,
      icon: Icons.psychology_alt_rounded,
      title: 'Bingung mulai dari mana?',
      subtitle: 'Jawab 2 pertanyaan, kami carikan yang paling cocok.',
      cta: 'Mulai kuis',
    );
  }
}

class _HelpBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _HelpBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _InfoBanner(
      onTap: onTap,
      color: AppStyle.success,
      icon: Icons.support_agent_rounded,
      title: 'Butuh bantuan memilih?',
      subtitle: 'Konsultasi gratis dengan tim kami via WhatsApp.',
      cta: 'Chat tim',
    );
  }
}

/// Flat informational banner with a call to action.
///
/// Was a saturated gradient card with sparkles in two different accent colours.
/// Two loud cards stacked mid-page is exactly what read as "playful app"; these
/// are now white cards with a blue icon tile, matching the rest of the system.
class _InfoBanner extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;

  const _InfoBanner({
    required this.onTap,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppStyle.getTextColor(context);
    final soft = AppStyle.getSubtitleColor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppStyle.rLg),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppStyle.getCardColor(context),
            borderRadius: BorderRadius.circular(AppStyle.rLg),
            border: Border.all(color: AppStyle.getBorderColor(context), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppStyle.rMd),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 21),
              ),
                  const SizedBox(width: 14),
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
                            color: fg,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          style: GoogleFonts.plusJakartaSans(
                            color: soft,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Label-first CTA: a tiny caption under an arrow glyph was
                  // unreadable at 9.5px, so the words now come first.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cta,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppStyle.spark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppStyle.spark,
                        size: 15,
                      ),
                    ],
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
