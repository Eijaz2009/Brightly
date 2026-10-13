import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/app_style.dart';
import '../providers/scholarship_provider.dart';
import '../widgets/scholarship_card.dart';
import 'detail_screen.dart';

class ScholarshipQuizScreen extends StatefulWidget {
  final List<Map<String, dynamic>> scholarships;
  final void Function(String title) onToggleBookmark;

  const ScholarshipQuizScreen({
    super.key,
    required this.scholarships,
    required this.onToggleBookmark,
  });

  @override
  State<ScholarshipQuizScreen> createState() =>
      _ScholarshipQuizScreenState();
}

class _ScholarshipQuizScreenState extends State<ScholarshipQuizScreen> {
  static const String _heroPrefix = 'quiz';

  late final PageController _pageController = PageController();
  int _currentStep = 0;

  String? _selectedRegion;
  String? _selectedLevel;

  static const List<String> _regions = [
    'Europe',
    'Asia',
    'America',
    'Australia',
    'Africa',
    'Anywhere',
  ];

  static const List<String> _levels = [
    'S1',
    'S2',
    'S3',
  ];

  /// Number of question pages (region + level).
  static const int _questionCount = 2;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _advance() {
    // Bug fix: this used to compare against `_levels.length` (3) while the
    // PageView only has 2 pages, so the quiz could never reach its results.
    if (_currentStep < _questionCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } else {
      setState(() => _currentStep = _questionCount);
    }
  }

  bool get _isResult => _currentStep >= _questionCount;

  void _restart() {
    setState(() {
      _currentStep = 0;
      _selectedRegion = null;
      _selectedLevel = null;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  bool _matches(Map<String, dynamic> s) {
    final level = ScholarshipCard.levelOf(s).toUpperCase();
    if (_selectedLevel != null && !level.contains(_selectedLevel!)) {
      return false;
    }

    final region = _selectedRegion;
    if (region == null || region == 'Anywhere') return true;

    final haystack = '${ScholarshipCard.countryOf(s)} '
            '${ScholarshipCard.subtitleOf(s)}'
        .toLowerCase();

    const map = <String, List<String>>{
      'Europe': [
        'uk', 'united kingdom', 'england', 'germany', 'hungary',
        'netherlands', 'france', 'switzerland', 'belgium', 'sweden',
        'italy', 'austria', 'finland', 'denmark', 'ireland', 'iceland',
        'greece', 'romania', 'bulgaria', 'spain', 'portugal', 'poland',
        'czech', 'slovakia', 'estonia', 'latvia', 'lithuania', 'serbia',
        'netherlands',
      ],
      'Asia': [
        'singapore', 'japan', 'korea', 'china', 'turkey', 'türkiye',
        'malaysia', 'indonesia', 'thailand', 'hong kong', 'philippines',
        'vietnam', 'india', 'israel', 'saudi', 'qatar', 'uae', 'oman',
        'bahrain', 'kuwait', 'jordan', 'iran', 'pakistan', 'bangladesh',
        'sri lanka', 'nepal',
      ],
      'America': [
        'usa', 'united states', 'canada', 'mexico', 'brazil', 'chile',
        'colombia', 'argentina', 'peru', 'uruguay', 'costa rica',
      ],
      'Australia': ['australia', 'new zealand'],
      'Africa': [
        'south africa', 'egypt', 'morocco', 'tunisia', 'algeria', 'libya',
        'nigeria', 'ghana', 'kenya', 'tanzania', 'uganda', 'ethiopia',
        'south africa', 'ivory coast', 'senegal', 'sudan', 'somalia',
      ],
    };

    final keywords = map[region];
    if (keywords == null) return true;
    return keywords.any(haystack.contains);
  }

  List<Map<String, dynamic>> get _results {
    if (_selectedLevel == null && _selectedRegion == null) {
      return widget.scholarships;
    }
    return widget.scholarships.where(_matches).toList(growable: false);
  }

  void _openDetail(Map<String, dynamic> data) {
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
          isBookmarked: false,
          heroTag: '$_heroPrefix::$title',
          onBookmarkTap: () => widget.onToggleBookmark(title),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: Column(
        children: [
          AppHeaders.pageHeader(
            context: context,
            title: 'Kuis Beasiswa',
            subtitle: _isResult
                ? 'Hasil rekomendasi'
                : 'Langkah ${_currentStep + 1} dari 2',
            leading: AppStyle.circleButton(
              context: context,
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
              size: 42,
            ),
          ),
          Expanded(child: _isResult ? _buildResults(context) : _buildQuestions()),
        ],
      ),
    );
  }

  Widget _buildQuestions() {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (i) => setState(() => _currentStep = i),
      children: [
        _QuestionStep(
          question: 'Di mana kamu ingin belajar?',
          subtitle: 'Pilih wilayah tujuan studi',
          options: _regions,
          selected: _selectedRegion,
          onSelect: (v) {
            setState(() => _selectedRegion = v);
            _advance();
          },
        ),
        _QuestionStep(
          question: 'Level pendidikan apa yang kamu tuju?',
          subtitle: 'Pilih jenjang studi',
          options: _levels,
          selected: _selectedLevel,
          onSelect: (v) {
            setState(() => _selectedLevel = v);
            _advance();
          },
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final results = _results;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Rekomendasi untukmu',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppStyle.getTextColor(context),
                  ),
                ),
              ),
              Text(
                '${results.length} ditemukan',
                style: GoogleFonts.plusJakartaSans(
                  color: AppStyle.accentOrange,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sentiment_dissatisfied_rounded,
                          size: 60,
                          color: AppStyle.primaryBlue.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Tidak ada cocokan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppStyle.getTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Coba ulangi dengan preferensi berbeda.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppStyle.getSubtitleColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final s = results[index];
                    final title = ScholarshipCard.titleOf(s);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ScholarshipCard(
                        scholarship: s,
                        heroPrefix: _heroPrefix,
                        isBookmarked: context
                            .read<ScholarshipProvider>()
                            .isBookmarked(title),
                        onBookmarkTap: () =>
                            context.read<ScholarshipProvider>().toggleBookmark(title),
                        onTap: () => _openDetail(s),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Ulangi Kuis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyle.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionStep extends StatelessWidget {
  final String question;
  final String subtitle;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _QuestionStep({
    required this.question,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
      children: [
        Text(
          question,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: AppStyle.getTextColor(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppStyle.getSubtitleColor(context),
          ),
        ),
        const SizedBox(height: 22),
        ...options.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(option),
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: selected == option
                        ? AppStyle.primaryBlue.withValues(alpha: 0.08)
                        : AppStyle.getCardColor(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected == option
                          ? AppStyle.primaryBlue
                          : AppStyle.getBorderColor(context),
                      width: selected == option ? 1.6 : 1.2,
                    ),
                    boxShadow: selected == option
                        ? null
                        : AppStyle.softShadow(context),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppStyle.getTextColor(context),
                          ),
                        ),
                      ),
                      Icon(
                        selected == option
                            ? Icons.check_circle_rounded
                            : Icons.chevron_right_rounded,
                        color: selected == option
                            ? AppStyle.primaryBlue
                            : AppStyle.getSubtitleColor(context),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
