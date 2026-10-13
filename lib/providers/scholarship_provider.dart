import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/scholarship_data.dart';
import '../widgets/scholarship_card.dart';

/// Single source of truth for scholarships + bookmarks.
///
/// Bug fixes baked in:
/// * listens to auth state (previously bookmarks never loaded because the
///   provider was constructed before Firebase restored the session)
/// * uses `set(..., merge: true)` instead of `update()` so writes never fail
///   with NOT_FOUND when the user document has not been created yet
/// * merges Firestore overrides for built-in scholarships so admin edits are
///   actually visible to users (previously silently discarded)
/// * no `orderBy` on a possibly-missing field, so no docs get dropped
class ScholarshipProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _scholarships = [];
  Set<String> _bookmarkedTitles = <String>{};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String _searchQuery = '';
  String? _error;
  StreamSubscription<User?>? _authSub;

  List<Map<String, dynamic>> get scholarships => _scholarships;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String get searchQuery => _searchQuery;
  String? get error => _error;

  List<String> get bookmarkedTitles => _bookmarkedTitles.toList(growable: false);

  bool isBookmarked(String title) => _bookmarkedTitles.contains(title);

  ScholarshipProvider({bool listenToAuth = true}) {
    if (!listenToAuth) return;
    // Firebase may not be initialised (widget tests, tooling). The app must
    // still render its local catalogue in that case.
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen(
        _onAuthChanged,
      );
    } catch (e) {
      debugPrint('Auth listener unavailable: $e');
    }
  }

  /// Seeds the catalogue without touching the network (tests, previews).
  @visibleForTesting
  void debugSeed(List<Map<String, dynamic>> data) {
    _scholarships = data;
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _onAuthChanged(User? user) async {
    await fetchScholarships();
    await loadSession();
  }

  /// Loads the current user's profile data (bookmarks, school, birth date).
  Future<Map<String, dynamic>> loadSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _bookmarkedTitles = <String>{};
      notifyListeners();
      return const {};
    }

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await ref.get();

      if (!doc.exists) {
        // Create the document so future writes never hit NOT_FOUND.
        final seed = <String, dynamic>{
          'nama': user.displayName ?? 'User',
          'name': user.displayName ?? 'User',
          'email': user.email ?? '',
          'role': 'user',
          'bookmarks': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        };
        await ref.set(seed);
        _bookmarkedTitles = <String>{};
        notifyListeners();
        return seed;
      }

      final data = doc.data();
      if (data != null && data['bookmarks'] is List) {
        _bookmarkedTitles =
            (data['bookmarks'] as List).map((e) => e.toString()).toSet();
      } else {
        _bookmarkedTitles = <String>{};
      }
      notifyListeners();
      return data ?? const <String, dynamic>{};
    } catch (e) {
      debugPrint('Error loading user session: $e');
      return const {};
    }
  }

  void replaceBookmarks(Iterable<String> titles) {
    _bookmarkedTitles = titles.toSet();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    notifyListeners();
  }

  // ───────────────────────────── derived lists ─────────────────────────────
  List<Map<String, dynamic>> get filteredScholarships {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _scholarships;
    return _scholarships.where((s) {
      return ScholarshipCard.titleOf(s).toLowerCase().contains(q) ||
          ScholarshipCard.countryOf(s).toLowerCase().contains(q) ||
          ScholarshipCard.subtitleOf(s).toLowerCase().contains(q) ||
          ScholarshipCard.levelOf(s).toLowerCase().contains(q) ||
          ScholarshipCard.fundingOf(s).toLowerCase().contains(q);
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> get savedScholarships => _scholarships
      .where((s) => _bookmarkedTitles.contains(ScholarshipCard.titleOf(s)))
      .toList(growable: false);

  List<Map<String, dynamic>> get featuredScholarships {
    final featured =
        _scholarships.where((s) => s['isFeatured'] == true).toList();
    if (featured.isNotEmpty) return featured;
    return _scholarships.take(5).toList(growable: false);
  }

  Map<String, int> get levelCounts {
    var s1 = 0, s2 = 0, s3 = 0;
    for (final s in _scholarships) {
      final level = ScholarshipCard.levelOf(s).toUpperCase();
      if (level.contains('S1')) s1++;
      if (level.contains('S2')) s2++;
      if (level.contains('S3')) s3++;
    }
    return {'S1': s1, 'S2': s2, 'S3': s3};
  }

  // ───────────────────────────── fetching ─────────────────────────────
  Future<void> refresh() => fetchScholarships();

  Future<void> fetchScholarships() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('scholarships').get();

      // Built-in catalogue, overridable by Firestore documents with the
      // same title (so admin edits are honoured).
      final defaults = ScholarshipData.defaultScholarships
          .map((s) => <String, dynamic>{...s, 'isDefault': true})
          .toList();
      final titleIndex = <String, int>{
        for (var i = 0; i < defaults.length; i++)
          ScholarshipCard.titleOf(defaults[i]): i,
      };

      final custom = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data.isEmpty) continue;
        final title = ScholarshipCard.titleOf(data);
        final normalized = <String, dynamic>{
          ...data,
          'id': doc.id,
          'doc': doc,
          'isDefault': false,
        };

        final idx = titleIndex[title];
        if (idx != null) {
          // Firestore version wins, but keep the original position.
          defaults[idx] = <String, dynamic>{
            ...normalized,
            'isDefault': true,
            'doc': doc,
            'id': doc.id,
          };
        } else {
          custom.add(normalized);
        }
      }

      // Custom entries first (newest unknown order), then built-ins.
      _scholarships = [...custom, ...defaults];
      _error = null;
    } catch (e) {
      debugPrint('Error fetching scholarships: $e');
      _error = 'Gagal memuat data beasiswa';
      if (_scholarships.isEmpty) {
        _scholarships = ScholarshipData.defaultScholarships
            .map((s) => <String, dynamic>{...s, 'isDefault': true})
            .toList();
      }
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  // ───────────────────────────── bookmarks ─────────────────────────────
  Future<void> toggleBookmark(String title) async {
    final wasBookmarked = _bookmarkedTitles.contains(title);

    // Optimistic update.
    if (wasBookmarked) {
      _bookmarkedTitles.remove(title);
    } else {
      _bookmarkedTitles.add(title);
    }
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // `set` + merge instead of `update` — the user document may not exist yet.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'bookmarks': _bookmarkedTitles.toList(growable: false)},
              SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error persisting bookmark: $e');
      // Roll back the optimistic update so the UI stays truthful.
      if (wasBookmarked) {
        _bookmarkedTitles.add(title);
      } else {
        _bookmarkedTitles.remove(title);
      }
      notifyListeners();
    }
  }
}
