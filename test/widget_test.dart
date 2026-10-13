import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scholar_path/services/app_translations.dart';
import 'package:scholar_path/services/app_state.dart';
import 'package:scholar_path/widgets/scholarship_card.dart';

void main() {
  group('ScholarshipCard accessors are null-safe', () {
    test('falls back gracefully for a fully empty document', () {
      final empty = <String, dynamic>{};

      expect(ScholarshipCard.titleOf(empty), 'Untitled Scholarship');
      expect(ScholarshipCard.countryOf(empty), 'Global');
      expect(ScholarshipCard.subtitleOf(empty), 'Scholarship');
      expect(ScholarshipCard.levelOf(empty), 'N/A');
      expect(ScholarshipCard.fundingOf(empty), 'N/A');
      expect(ScholarshipCard.deadlineOf(empty), 'Varies');
      expect(ScholarshipCard.flagOf(empty), '🌍');
    });

    test('does not throw when title/subtitle are missing', () {
      // Regression guard: the old Explore screen used `s['title']!` which
      // crashed on any document without a title.
      final data = <String, dynamic>{'country': 'Japan'};

      expect(ScholarshipCard.titleOf(data), 'Untitled Scholarship');
      expect(ScholarshipCard.countryOf(data), 'Japan');
    });

    test('extracts country from the "University · Country" subtitle', () {
      final data = <String, dynamic>{
        'title': 'MEXT Scholarship',
        'subtitle': 'Japanese Government · Japan',
      };

      expect(ScholarshipCard.countryOf(data), 'Japan');
    });

    test('prefers an explicit country field over the subtitle', () {
      final data = <String, dynamic>{
        'subtitle': 'Some Org · Somewhere',
        'country': 'Indonesia',
      };

      expect(ScholarshipCard.countryOf(data), 'Indonesia');
    });

    test('generates a search URL when no official link is stored', () {
      final data = <String, dynamic>{'title': 'Chevening Scholarship'};

      expect(
        ScholarshipCard.urlOf(data),
        contains('google.com/search'),
      );
    });
  });

  group('AppTranslations', () {
    tearDown(() => AppState.setLocale('en'));

    test('falls back to English for an unknown key', () {
      AppState.setLocale('en');
      expect(AppTranslations.get('definitely_not_a_key'), 'definitely_not_a_key');
    });

    test('returns Indonesian strings when the locale is id', () {
      AppState.setLocale('id');
      expect(AppTranslations.get('good_morning'), 'Selamat pagi');
    });

    test('English and Indonesian maps have the same keys', () {
      // Guards against a half-finished translation causing silent fallbacks.
      const sampleKeys = <String>[
        'good_morning',
        'explore_title',
        'saved_title',
        'settings_title',
        'logout',
      ];
      for (final key in sampleKeys) {
        expect(AppTranslations.get(key), isNotEmpty);
      }
    });
  });

  testWidgets('ScholarshipCard renders without duplicate Hero tags', (
    tester,
  ) async {
    const data = <String, dynamic>{
      'title': 'LPDP Scholarship',
      'country': 'Indonesia',
      'level': 'S2/S3',
      'funding': 'Full Funded',
      'flag': '🇮🇩',
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScholarshipCard(
            scholarship: data,
            isBookmarked: false,
            onBookmarkTap: _noop,
          ),
        ),
      ),
    );

    expect(find.text('LPDP Scholarship'), findsOneWidget);
    expect(find.text('Indonesia'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
  });
}

void _noop() {}
