import 'package:flutter_test/flutter_test.dart';

import 'package:scholar_path/services/facebook_auth_config.dart';

void main() {
  group('FacebookAuthDiagnosis.from', () {
    test('a closed popup or web context is a cancellation, not an error', () {
      for (final raw in const [
        'FirebaseAuthException: popup-closed-by-user',
        'FirebaseAuthException: user-cancelled',
        'FirebaseAuthException: web-context-cancelled',
        'The operation was canceled.',
        '12501',
      ]) {
        final d = FacebookAuthDiagnosis.from(raw);
        expect(
          d.isCancelled,
          isTrue,
          reason: 'should be treated as cancellation: $raw',
        );
        expect(d.showSetupSteps, isFalse);
      }
    });

    test('operation-not-allowed explains setup steps', () {
      final d = FacebookAuthDiagnosis.from(
        'FirebaseAuthException: operation-not-allowed',
      );
      expect(d.showSetupSteps, isTrue);
      expect(d.isCancelled, isFalse);
      expect(d.message, contains('Firebase Console'));
    });

    test('configuration-not-found explains setup steps', () {
      final d = FacebookAuthDiagnosis.from(
        'FirebaseAuthException: configuration-not-found',
      );
      expect(d.showSetupSteps, isTrue);
      expect(d.isCancelled, isFalse);
    });

    test('channel-error and TOS exceptions explain Android SDK setup steps', () {
      final d = FacebookAuthDiagnosis.from(
        'Facebook auth error: channel-error dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.signInWithProvider',
      );
      expect(d.showSetupSteps, isTrue);
      expect(d.isCancelled, isFalse);
      expect(d.message, contains('Meta'));
    });

    test('network errors are properly identified', () {
      final d = FacebookAuthDiagnosis.from(
        'SocketException: Failed to connect',
      );
      expect(d.message.toLowerCase(), contains('koneksi'));
      expect(d.showSetupSteps, isFalse);
    });

    test('setup steps list has Firebase and Meta instructions', () {
      final text = FacebookAuthConfig.setupSteps.join(' ');
      expect(text, contains('Firebase Console'));
      expect(text, contains('Meta'));
      expect(text, contains('App ID'));
    });
  });
}
