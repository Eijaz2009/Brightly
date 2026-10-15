import 'package:flutter_test/flutter_test.dart';

import 'package:scholar_path/firebase_options.dart';
import 'package:scholar_path/services/google_auth_config.dart';

void main() {
  group('GoogleAuthDiagnosis.from', () {
    test('a closed popup is a cancellation, not an error', () {
      // Regression guard: closing the popup is a normal user action. Showing a
      // red banner for it makes the app look broken.
      for (final raw in const [
        'GoogleSignInException: popup_closed',
        'popup_closed',
        'FirebaseAuthException: popup-closed-by-user',
        'FirebaseAuthException: user-cancelled',
        'The operation was canceled.',
        'sign_in_with_apple: 12501',
      ]) {
        final d = GoogleAuthDiagnosis.from(raw);
        expect(
          d.isCancelled,
          isTrue,
          reason: 'should be treated as cancellation: $raw',
        );
        expect(d.showSetupSteps, isFalse);
      }
    });

    test('a blocked popup explains how to unblock it', () {
      final d = GoogleAuthDiagnosis.from('FirebaseAuthException: popup-blocked');
      expect(d.outcome, GoogleAuthOutcome.popupBlocked);
      expect(d.showSetupSteps, isFalse);
      expect(d.message.toLowerCase(), contains('pop-up'));
    });

    test('redirect_uri_mismatch is a configuration problem', () {
      // The error that broke Google sign-in on web. Origin registration cannot
      // fix this one — it is the redirect_uri that is unregistered.
      final d = GoogleAuthDiagnosis.from('Error 400: redirect_uri_mismatch');
      expect(d.outcome, GoogleAuthOutcome.configuration);
      expect(d.showSetupSteps, isTrue);
    });

    test('origin_mismatch is a configuration problem', () {
      final d = GoogleAuthDiagnosis.from(
        'GoogleSignInException: Error 400: origin_mismatch',
      );
      expect(d.outcome, GoogleAuthOutcome.configuration);
      expect(d.showSetupSteps, isTrue);
    });

    test('firebase unauthorized-domain names Authorized domains', () {
      final d = GoogleAuthDiagnosis.from(
        '[firebase_auth] FirebaseAuthException: unauthorized-domain',
      );
      expect(d.outcome, GoogleAuthOutcome.configuration);
      expect(d.showSetupSteps, isTrue);
      expect(d.message, contains('Authorized domains'));
    });

    test('invalid client id is a credentials problem', () {
      final d = GoogleAuthDiagnosis.from('Error 401: invalid_client');
      expect(d.outcome, GoogleAuthOutcome.configuration);
      expect(d.showSetupSteps, isTrue);
    });

    test('quota errors are throttling, not user error', () {
      for (final raw in const [
        'Error 429: too_many_requests',
        'QUOTA_EXCEEDED',
      ]) {
        expect(
          GoogleAuthDiagnosis.from(raw).outcome,
          GoogleAuthOutcome.throttled,
          reason: raw,
        );
      }
    });

    test('network failures are reported as network', () {
      expect(
        GoogleAuthDiagnosis.from('XMLHttpRequest error: Failed to fetch')
            .outcome,
        GoogleAuthOutcome.network,
      );
    });

    test('an unknown error still yields a safe Indonesian message', () {
      final d = GoogleAuthDiagnosis.from('PlatformException(something-odd)');
      expect(d.outcome, GoogleAuthOutcome.unknown);
      expect(d.message, isNotEmpty);
      // Never leak a raw exception into the UI.
      expect(d.message, isNot(contains('PlatformException')));
      expect(d.showSetupSteps, isFalse);
    });
  });

  group('GoogleAuthConfig', () {
    test('the native server client id is the Web client id (type 3)', () {
      expect(GoogleAuthConfig.isConfigured, isTrue);
      expect(
        GoogleAuthConfig.serverClientId,
        GoogleAuthConfig.webClientId,
        reason: 'must be the Web client id so Firebase accepts the ID token',
      );
    });

    test('the Android client id matches firebase_options.dart', () {
      expect(
        GoogleAuthConfig.androidClientId,
        DefaultFirebaseOptions.ios.androidClientId,
        reason: 'must stay in sync with androidClientId in firebase_options.dart',
      );
    });

    test('web setup steps point at Firebase Authorized domains', () {
      final text = GoogleAuthConfig.webSetupSteps.join(' ');
      expect(text, contains('Authorized domains'));
      expect(text, contains('localhost'));
      expect(text, contains('127.0.0.1'));
    });

    test('the origin help message points at Authorized domains', () {
      expect(GoogleAuthConfig.webOriginHelp, contains('Authorized domains'));
    });
  });
}
