import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Where the Gemini key was found (or expected to be found).
enum AiKeySource {
  /// `--dart-define=GEMINI_API_KEY=...`
  dartDefine,

  /// Firestore document `config/api_keys` → field `gemini_api_key`
  firestore,

  /// Local, git-ignored file `assets/ai_config.json` (development escape hatch)
  localFile,
}

/// Why the AI feature could not start.
enum AiConfigFailure {
  /// No key in any supported location.
  missing,

  /// Firestore refused the read (usually signed out, or old security rules).
  permissionDenied,

  /// A key exists but every model name was rejected (bad/expired key).
  rejectedKey,

  /// Network unreachable.
  network,
}

class AiConfigResult {
  final String apiKey;
  final AiKeySource? source;

  /// Null when [apiKey] is non-empty.
  final AiConfigFailure? failure;

  /// Human-readable detail for the diagnostics panel.
  final String detail;

  const AiConfigResult({
    required this.apiKey,
    this.source,
    this.failure,
    this.detail = '',
  });

  bool get isReady => apiKey.isNotEmpty;

  static const empty = AiConfigResult(
    apiKey: '',
    failure: AiConfigFailure.missing,
    detail: 'No API key found in any configured location.',
  );
}

/// Resolves the Gemini API key from, in order:
///
/// 1. `--dart-define=GEMINI_API_KEY=...` — fastest for local development
///    ```bash
///    flutter run --dart-define=GEMINI_API_KEY=AIza...
///    ```
/// 2. Firestore `config/api_keys` → `gemini_api_key` — the shared option; the
///    admin writes it once and every device picks it up with no rebuild.
/// 3. `assets/ai_config.json` — optional local file, ignored by git and not
///    registered in `pubspec.yaml`, so it never breaks the build when absent.
///
/// The key is deliberately *never* committed to the repository. For production,
/// prefer moving the Gemini call into a Cloud Function so the key never ships
/// to a client at all.
class AiConfig {
  static const String _defineKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _localFilePath = 'assets/ai_config.json';
  static const String _firestorePath = 'config/api_keys';
  static const String _firestoreField = 'gemini_api_key';

  /// Rejects keys that are obviously placeholders so a blank Firestore field
  /// does not masquerade as a working configuration.
  static bool _looksValid(String value) {
    final key = value.trim();
    if (key.length < 20) return false;
    if (key == 'YOUR_API_KEY' || key.contains('xxxx')) return false;
    return true;
  }

  static Future<AiConfigResult> resolve() async {
    // 1) Build-time define wins: fastest, no network.
    if (_looksValid(_defineKey)) {
      return AiConfigResult(
        apiKey: _defineKey.trim(),
        source: AiKeySource.dartDefine,
      );
    }

    // 2) Firestore.
    try {
      final doc = await FirebaseFirestore.instance.doc(_firestorePath).get();
      final raw = doc.data()?[_firestoreField]?.toString().trim() ?? '';
      if (_looksValid(raw)) {
        return AiConfigResult(
          apiKey: raw,
          source: AiKeySource.firestore,
        );
      }
      debugPrint(
        'AiConfig: $_firestorePath exists but "$_firestoreField" is empty.',
      );
    } on FirebaseException catch (e) {
      debugPrint('AiConfig: Firestore read failed (${e.code}).');
      if (e.code == 'permission-denied') {
        // Fall through: the local file / define may still work. Only report
        // permissionDenied if nothing else supplies a key.
        final fallback = await _tryLocalFile();
        if (fallback != null) return fallback;
        return const AiConfigResult(
          apiKey: '',
          failure: AiConfigFailure.permissionDenied,
          detail:
              'Firestore menolak pembacaan $_firestorePath. '
              'Pastikan user sudah login dan security rules memdeploy versi terbaru.',
        );
      }
    } catch (e) {
      debugPrint('AiConfig: unexpected Firestore error: $e');
    }

    // 3) Local file.
    final local = await _tryLocalFile();
    if (local != null) return local;

    return const AiConfigResult(
      apiKey: '',
      failure: AiConfigFailure.missing,
      detail: 'Belum ada Gemini API key yang dikonfigurasi.',
    );
  }

  static Future<AiConfigResult?> _tryLocalFile() async {
    try {
      final raw = await rootBundle.loadString(_localFilePath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final key = decoded[_firestoreField]?.toString().trim() ?? '';
      if (!_looksValid(key)) return null;
      return AiConfigResult(apiKey: key, source: AiKeySource.localFile);
    } catch (_) {
      // Asset not bundled — the expected default.
      return null;
    }
  }

  /// Copy-pasteable setup instructions for the error screen.
  static List<String> get setupSteps => const <String>[
    'Buat dokumen Firestore: config/api_keys',
    'Tambahkan field (text): gemini_api_key',
    'Tempel Gemini API key ke field tersebut',
    'Atau jalankan app dengan: --dart-define=GEMINI_API_KEY=<key>',
  ];

  static String labelFor(AiKeySource source) => switch (source) {
    AiKeySource.dartDefine => 'dart-define',
    AiKeySource.firestore => 'Firestore config/api_keys',
    AiKeySource.localFile => 'assets/ai_config.json',
  };
}
