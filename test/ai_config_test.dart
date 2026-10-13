import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:scholar_path/services/ai_config.dart';

void main() {
  group('AiConfig', () {
    test('resolves a key when any source provides one', () async {
      final result = await AiConfig.resolve();

      if (result.isReady) {
        // A key was found — it must be non-trivial and correctly attributed.
        expect(result.apiKey.trim().length, greaterThanOrEqualTo(20));
        expect(result.failure, isNull);
        expect(result.source, isNotNull);
        expect(AiConfig.labelFor(result.source!), isNotEmpty);
      } else {
        // Nothing configured: the failure must be explained, not silent.
        expect(result.failure, isNotNull);
        expect(result.detail, isNotEmpty);
        expect(result.apiKey, isEmpty);
      }
    });

    test('never returns an obviously invalid key', () async {
      // Regression guard: an empty Firestore field used to be handed straight
      // to the SDK, which then failed with an opaque error.
      final result = await AiConfig.resolve();

      if (result.apiKey.isNotEmpty) {
        expect(result.apiKey.trim(), isNot('YOUR_API_KEY'));
        expect(result.apiKey, isNot(contains('xxxx')));
        expect(result.apiKey.trim().length, greaterThanOrEqualTo(20));
      }
    });

    test('setup steps name the exact document and field', () {
      expect(AiConfig.setupSteps, isNotEmpty);
      final text = AiConfig.setupSteps.join(' ');
      expect(text, contains('config/api_keys'));
      expect(text, contains('gemini_api_key'));
      expect(
        text,
        contains('GEMINI_API_KEY'),
        reason: 'the dart-define escape hatch must stay documented',
      );
    });

    test('source labels are human readable', () {
      expect(AiConfig.labelFor(AiKeySource.dartDefine), 'dart-define');
      expect(
        AiConfig.labelFor(AiKeySource.firestore),
        'Firestore config/api_keys',
      );
      expect(
        AiConfig.labelFor(AiKeySource.localFile),
        'assets/ai_config.json',
      );
    });

    test('bundled ai_config.json is valid JSON with a string key field', () {
      // The app reads this file at runtime; a syntax error here would silently
      // disable the AI feature on every launch.
      final file = File('assets/ai_config.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'assets/ai_config.json must be committed (with an empty key) so '
            'the build never fails on a missing asset',
      );

      final decoded = jsonDecode(file.readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());
      expect(decoded.containsKey('gemini_api_key'), isTrue);
      expect(decoded['gemini_api_key'], isA<String>());
    });
  });
}
