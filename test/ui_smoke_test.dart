import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:scholar_path/main.dart';
import 'package:scholar_path/models/scholarship_data.dart';
import 'package:scholar_path/providers/scholarship_provider.dart';
import 'package:scholar_path/services/app_style.dart';
import 'package:scholar_path/screens/detail_screen.dart';
import 'package:scholar_path/screens/explore_screen.dart';
import 'package:scholar_path/screens/help_support_screen.dart';
import 'package:scholar_path/screens/home_screen.dart';
import 'package:scholar_path/screens/profile_screen.dart';
import 'package:scholar_path/screens/quiz_screen.dart';
import 'package:scholar_path/screens/saved_screen.dart';
import 'package:scholar_path/widgets/scholarship_card.dart';

/// Layout smoke tests.
///
/// These do not check pixels — they make Flutter *report* RenderFlex
/// overflows, off-screen taps and missing-provider errors, which are the
/// failure modes that a static design pass cannot catch.
void main() {
  final sample = <Map<String, dynamic>>[
    for (final s in ScholarshipData.defaultScholarships.take(6))
      <String, dynamic>{...s},
    // A deliberately incomplete document: proves the null-safe accessors hold.
    <String, dynamic>{'title': 'Beasiswa Tanpa Metadata'},
  ];

  Widget wrap(Widget child, {ScholarshipProvider? provider}) {
    final p = provider ?? ScholarshipProvider(listenToAuth: false)..debugSeed(sample);
    return ChangeNotifierProvider<ScholarshipProvider>.value(
      value: p,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: child,
      ),
    );
  }

  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    ScholarshipProvider? provider,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(child, provider: provider));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Drains every pending exception and reports it with the full render
  /// diagnostics, so overflows name the offending widget instead of just
  /// saying "overflowed by N pixels".
  void expectClean(WidgetTester tester) {
    Object? error;
    while ((error = tester.takeException()) != null) {
      if (error is FlutterError) {
        fail(
          'LAYOUT ERROR: ${error.message}\n'
          '${error.toStringDeep()}',
        );
      }
      fail('UNCAUGHT: $error');
    }
  }

  /// Scrolls every scroll view in the tree so lazily built slivers and off-screen
  /// rows get laid out too — that is where overflows usually hide.
  Future<void> scrollAll(WidgetTester tester) async {
    for (var round = 0; round < 5; round++) {
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isEmpty) return;
      for (final finder in scrollables.evaluate().toList()) {
        await tester.drag(
          find.byWidget(finder.widget),
          const Offset(0, -380),
          warnIfMissed: false,
        );
      }
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  group('Home', () {
    testWidgets('renders every tab without overflow', (tester) async {
      await pumpAt(tester, const HomeScreen());
      await tester.pump(const Duration(milliseconds: 400));
      await scrollAll(tester);

      // Walk all four tabs; IndexedStack keeps them alive simultaneously.
      // Scope to the nav bar so a label that also appears in page content
      // (e.g. "Saved") cannot be tapped by accident.
      final nav = find.byKey(AppStyle.bottomNavKey);
      expect(nav, findsOneWidget);

      for (final label in ['Explore', 'Saved', 'Profil', 'Home']) {
        final target = find.descendant(of: nav, matching: find.text(label));
        expect(
          target,
          findsOneWidget,
          reason: 'nav bar must expose every tab label, not just the selected one',
        );
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 350));
        await scrollAll(tester);
      }
      expectClean(tester);
    });

    testWidgets('search field filters the list', (tester) async {
      await pumpAt(tester, const HomeScreen());
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(find.byType(TextField).first, 'zzzznomatch');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Tidak ada hasil'), findsOneWidget);
      expectClean(tester);
    });
  });

  testWidgets('Explore renders categories and empty state', (tester) async {
    await pumpAt(tester, const ExploreScreen());
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Telusuri kategori'), findsOneWidget);
    expectClean(tester);
  });

  testWidgets('Saved shows the friendly empty state', (tester) async {
    await pumpAt(tester, const SavedScreen());
    await tester.pump(const Duration(milliseconds: 400));
    // Locale defaults to English in tests.
    expect(find.text('No saved scholarships yet'), findsOneWidget);
    expectClean(tester);
  });

  testWidgets('Saved lists bookmarks when present', (tester) async {
    final provider = ScholarshipProvider(listenToAuth: false)
      ..debugSeed(sample)
      ..replaceBookmarks(<String>[ScholarshipCard.titleOf(sample.first)]);

    await pumpAt(tester, const SavedScreen(), provider: provider);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(ScholarshipCard.titleOf(sample.first)), findsWidgets);
    expectClean(tester);
  });

  testWidgets('Profile renders stats and menus', (tester) async {
    await pumpAt(tester, const ProfileScreen());
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('AKUN'), findsOneWidget);
    expect(find.text('PREFERENSI'), findsOneWidget);
    expectClean(tester);
  });

  testWidgets('Detail renders without overflow', (tester) async {
    await pumpAt(
      tester,
      const DetailScreen(
        flag: '🇬🇧',
        title: 'Chevening Scholarship',
        country: 'United Kingdom',
        level: 'S2',
        funding: 'Full Funded',
        deadline: 'Nov 2026',
        officialUrl: 'https://www.chevening.org/',
        isBookmarked: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Chevening Scholarship'), findsOneWidget);
    expect(find.textContaining('DEADLINE'.toUpperCase()), findsOneWidget);
    expectClean(tester);
  });

  testWidgets('Quiz renders the first question', (tester) async {
    await pumpAt(
      tester,
      ScholarshipQuizScreen(
        scholarships: sample,
        onToggleBookmark: (_) {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Di mana kamu'), findsOneWidget);
    expectClean(tester);
  });

  testWidgets('Quiz reaches the results view', (tester) async {
    await pumpAt(
      tester,
      ScholarshipQuizScreen(
        scholarships: sample,
        onToggleBookmark: (_) {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Europe'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('S2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Rekomendasi untukmu'), findsOneWidget);
    expectClean(tester);
  });

  testWidgets('Help support renders cards and FAQ', (tester) async {
    await pumpAt(tester, const HelpSupportScreen());
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Bantuan'), findsOneWidget);
    expectClean(tester);
  });

  group('ScholarshipCard', () {
    testWidgets('survives an almost-empty document', (tester) async {
      await pumpAt(
        tester,
        Scaffold(
          body: ScholarshipCard(
            scholarship: const <String, dynamic>{},
            isBookmarked: false,
            onBookmarkTap: () {},
          ),
        ),
      );
      expectClean(tester);
    });

    testWidgets('survives a very long title and country', (tester) async {
      await pumpAt(
        tester,
        Scaffold(
          body: ScholarshipCard(
            scholarship: const <String, dynamic>{
              'title':
                  'International Scholarship Programme for Students Pursuing '
                  'Postgraduate Degrees in Renewable Energy Engineering and '
                  'Sustainable Development Studies',
              'country':
                  'United Kingdom of Great Britain and Northern Ireland',
              'level': 'S2/S3',
              'funding': 'Fully Funded International Programme',
              'flag': '🇬🇧',
            },
            isBookmarked: true,
            onBookmarkTap: () {},
          ),
        ),
      );
      expectClean(tester);
    });
  });

  group('Safe-area / header spacing', () {
    /// Pumps a bare subtree with an explicit MediaQuery inset so the inset maths
    /// is deterministic and does not depend on Scaffold internals.
    Future<void> pumpWithInset(
      WidgetTester tester, {
      required double top,
      required double bottom,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<ScholarshipProvider>.value(
          value: ScholarshipProvider(listenToAuth: false)..debugSeed(sample),
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 844),
                padding: EdgeInsets.only(top: top, bottom: bottom),
                viewPadding: EdgeInsets.only(top: top, bottom: bottom),
              ),
              child: const HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('headers clear the status bar inset', (tester) async {
      // 141 physical px at dpr 3 = 47 logical px of status bar.
      await pumpWithInset(tester, top: 47, bottom: 34);

      // Top row of the greeting header. It reads "<greeting>, <name>", so match
      // the combined string rather than the bare display name.
      final headerTop = find.textContaining('Teman');
      expect(headerTop, findsWidgets);

      final headerBox = tester.renderObject<RenderBox>(headerTop.first);
      final top = headerBox.localToGlobal(Offset.zero).dy;

      expect(
        top,
        greaterThan(47),
        reason: 'header must render below the 47px status bar',
      );
      expectClean(tester);
    });

    testWidgets('a notch-sized inset is clamped, not doubled', (tester) async {
      // Tall insets (landscape, some tablets) must not push content away.
      await pumpWithInset(tester, top: 90, bottom: 34);

      final headerTop = find.textContaining('Teman').first;
      final headerBox = tester.renderObject<RenderBox>(headerTop);
      final top = headerBox.localToGlobal(Offset.zero).dy;

      expect(top, lessThan(110));
      expectClean(tester);
    });

    testWidgets('with no inset there is still a comfortable gap', (
      tester,
    ) async {
      await pumpWithInset(tester, top: 0, bottom: 0);

      final headerTop = find.textContaining('Teman').first;
      final headerBox = tester.renderObject<RenderBox>(headerTop);
      final top = headerBox.localToGlobal(Offset.zero).dy;

      expect(top, greaterThanOrEqualTo(12));
      expectClean(tester);
    });
  });


  group('Theme', () {
    test('light and dark are both constructible', () {
      expect(buildTheme(Brightness.light).brightness, Brightness.light);
      expect(buildTheme(Brightness.dark).brightness, Brightness.dark);
    });

    test('surfaces differ between brightnesses', () {
      final light = buildTheme(Brightness.light).scaffoldBackgroundColor;
      final dark = buildTheme(Brightness.dark).scaffoldBackgroundColor;
      expect(light, isNot(dark));
    });
  });
}
