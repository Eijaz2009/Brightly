import 'package:flutter_test/flutter_test.dart';

import 'package:scholar_path/models/scholarship_data.dart';
import 'package:scholar_path/widgets/scholarship_card.dart';

void main() {
  group('Built-in scholarship catalogue', () {
    test('is not empty', () {
      expect(ScholarshipData.defaultScholarships, isNotEmpty);
    });

    test('every entry has the fields the UI renders', () {
      for (final s in ScholarshipData.defaultScholarships) {
        expect(
          ScholarshipCard.titleOf(s),
          isNot('Untitled Scholarship'),
          reason: 'missing title for $s',
        );
        expect(ScholarshipCard.flagOf(s), isNotEmpty);
        expect(ScholarshipCard.levelOf(s), isNotEmpty);
        expect(ScholarshipCard.fundingOf(s), isNotEmpty);
        expect(ScholarshipCard.deadlineOf(s), isNotEmpty);
        expect(
          ScholarshipCard.urlOf(s),
          startsWith('http'),
          reason: 'invalid url: ${ScholarshipCard.urlOf(s)}',
        );
      }
    });

    test('titles are unique (used as bookmark keys and Hero tags)', () {
      final titles = ScholarshipData.defaultScholarships
          .map(ScholarshipCard.titleOf)
          .toList();
      final duplicates =
          titles.where((t) => titles.where((x) => x == t).length > 1).toSet();

      // Duplicate titles would make Hero tags collide and bookmarks ambiguous.
      expect(duplicates, isEmpty);
    });

    test('hero tags stay unique per prefix', () {
      const data = <String, dynamic>{'title': 'LPDP Scholarship'};

      expect(
        ScholarshipCard(
          scholarship: data,
          isBookmarked: false,
          onBookmarkTap: () {},
          heroPrefix: 'latest',
        ).heroTag,
        'latest::LPDP Scholarship',
      );
      expect(
        ScholarshipCard(
          scholarship: data,
          isBookmarked: false,
          onBookmarkTap: () {},
          heroPrefix: 'explore',
        ).heroTag,
        'explore::LPDP Scholarship',
      );
    });
  });
}
