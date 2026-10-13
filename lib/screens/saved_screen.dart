import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/scholarship_provider.dart';
import '../services/app_style.dart';
import '../services/app_translations.dart';
import '../widgets/scholarship_card.dart';
import 'detail_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  static const String _heroPrefix = 'saved';

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
          isBookmarked: true,
          heroTag: '$_heroPrefix::$title',
          onBookmarkTap: () => provider.toggleBookmark(title),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScholarshipProvider>();
    final query = _query.trim().toLowerCase();

    final items = provider.savedScholarships.where((s) {
      if (query.isEmpty) return true;
      return ScholarshipCard.titleOf(s).toLowerCase().contains(query) ||
          ScholarshipCard.countryOf(s).toLowerCase().contains(query);
    }).toList(growable: false);

    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: AppStyle.background(
        context: context,
        child: Column(
          children: [
            AppHeaders.pageHeader(
              context: context,
              title: 'Tersimpan',
              subtitle: items.isEmpty
                  ? 'Koleksi映画祭mu'
                  : '${items.length} beasiswa tersimpan',
              showSearch: true,
              searchController: _searchController,
              onSearchChanged: (v) => setState(() => _query = v),
              onSearchCleared: () => setState(() => _query = ''),
              searchHint: 'Cari di simpanan...',
              trailing: items.isEmpty
                  ? null
                  : _CountBadge(count: items.length),
            ),
            Expanded(
              child: items.isEmpty
                  ? AppStyle.emptyState(
                      context: context,
                      icon: query.isEmpty
                          ? Icons.bookmark_border_rounded
                          : Icons.search_off_rounded,
                      title: query.isEmpty
                          ? AppTranslations.get('no_saved')
                          : 'Tidak ada hasil untuk "$query"',
                      subtitle: query.isEmpty
                          ? AppTranslations.get('no_saved_desc')
                          : 'Coba kata kunci lain.',
                      color: AppStyle.spark,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        18,
                        20,
                        AppStyle.bottomInset(context) + 84,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final s = items[index];
                        final title = ScholarshipCard.titleOf(s);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ScholarshipCard(
                            scholarship: s,
                            heroPrefix: _heroPrefix,
                            isBookmarked: true,
                            onBookmarkTap: () =>
                                provider.toggleBookmark(title),
                            onTap: () => _openDetail(s),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppStyle.spark.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppStyle.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bookmark_rounded,
            size: 15,
            color: AppStyle.spark,
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: AppStyle.font(
              context,
              size: 14,
              weight: FontWeight.w800,
              color: AppStyle.spark,
            ),
          ),
        ],
      ),
    );
  }
}
