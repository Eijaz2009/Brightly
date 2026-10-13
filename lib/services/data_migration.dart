import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/scholarship_data.dart';

/// One-off seeding of the built-in scholarship catalogue.
///
/// Notes:
/// * Writes require an authenticated admin (see `firestore.rules`). When run
///   anonymously it no-ops instead of spamming a hundred permission errors.
/// * Runs with a hard timeout so an unreachable Firestore can never stall the
///   app.
class DataMigration {
  static bool _hasRun = false;

  static Future<void> uploadDefaultScholarships() async {
    if (_hasRun) return;
    _hasRun = true;

    try {
      await _run().timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('Migration skipped: $e');
    }
  }

  static Future<void> _run() async {
    final scholarships = FirebaseFirestore.instance.collection('scholarships');

    final snapshot = await scholarships.limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      debugPrint('Migration: catalogue already present, skipping.');
      return;
    }

    // Anonymous users cannot write — bail out quietly and rely on the
    // built-in local catalogue.
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('Migration: not authenticated, using local catalogue only.');
      return;
    }

    debugPrint('Migration: uploading default scholarships...');
    final batch = FirebaseFirestore.instance.batch();
    var pending = 0;

    for (final s in ScholarshipData.defaultScholarships) {
      batch.set(scholarships.doc(), <String, dynamic>{
        ...s,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      pending++;
      // Firestore batches are capped at 500 writes.
      if (pending == 400) {
        await batch.commit();
        pending = 0;
      }
    }

    if (pending > 0) await batch.commit();
    debugPrint('Migration: catalogue uploaded.');
  }
}
