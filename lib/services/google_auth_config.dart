/// Google OAuth configuration for Android/iOS.
///
/// ## Web does not need a client id
///
/// The web build signs in through `signInWithPopup(GoogleAuthProvider())`. The
/// Firebase JS SDK constructs the OAuth request from the project's
/// `authDomain`, so no OAuth client id has to be baked into Dart.
///
/// This matters here. The `google_sign_in` web path sends an explicit
/// implicit-flow request to a hard-coded client id
/// (`869400565061-pqou8v9ad47fgl76vev3ifqnes0hojt8…`, app name **"Potato App"**).
/// That client is of type Android/iOS, so Google rejected *every* web origin
/// with `Error 400: redirect_uri_mismatch` / `origin_mismatch` — registering
/// `http://localhost` could not have fixed it, because the client itself was
/// wrong. Firebase's own flow avoids that class of misconfiguration.
///
/// ## Native
///
/// Android and iOS need a Web-type `serverClientId` so the obtained ID token
/// is accepted by the Firebase project. This MUST be the **Web (type 3)**
/// OAuth client from `google-services.json`, NOT the Android (type 1) one.
/// Memakai client Android sebagai `serverClientId` membuat `idToken` null dan
/// Firebase menolak credential dengan `invalid-credential` — persis popup
/// "Login Google gagal. Silakan coba lagi." yang generik.
class GoogleAuthConfig {
  /// Web (type 3) OAuth client dari `google-services.json`.
  /// Jangan diganti dengan client Android (type 1) atau iOS.
  static const String defaultServerClientId =
      '869400565061-j9as037t4p92he7oeisfhd3iguh0luis.apps.googleusercontent.com';

  static const String _serverClientIdOverride = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Client id sent to Google on Android/iOS.
  static String get serverClientId =>
      _serverClientIdOverride.isNotEmpty
          ? _serverClientIdOverride
          : defaultServerClientId;

  /// Sanity check that we are not handing Google a malformed client id.
  static bool get isConfigured =>
      serverClientId.trim().length > 20 &&
      serverClientId.endsWith('.apps.googleusercontent.com');

  /// Reminders for the remaining web-side requirement.
  ///
  /// The popup no longer needs OAuth origins, but Firebase Auth itself still
  /// validates the calling origin against **Authorized domains** in the
  /// Firebase console.
  static List<String> get webSetupSteps => const <String>[
    'Firebase Console → Authentication → Settings → Authorized domains',
    'Pastikan "localhost" dan "127.0.0.1" terdaftar',
    'Tambahkan domain produksi (mis. domainmu.com) sebelum deploy',
  ];

  /// Syarat yang harus benar untuk login Google di Android/iOS.
  static List<String> get nativeSetupSteps => const <String>[
    'Firebase Console → Project settings → aplikasi Android ini',
    'Pastikan package name: com.example.scholar_path',
    'Tambahkan SHA-1 debug DAN SHA-1 release (keytool / Play App signing)',
    'Download ulang google-services.json lalu rebuild aplikasinya',
    'Aktifkan provider Google di Authentication → Sign-in method',
  ];

  /// Shown when the popup is rejected because of the calling origin.
  static const String webOriginHelp =
      'Popup login Google ditolak karena origin ini tidak terdaftar. '
      'Tambahkan domain ini di Firebase Console → Authentication → Settings → '
      'Authorized domains.';
}

/// How a Google sign-in attempt ended.
enum GoogleAuthOutcome {
  success,

  /// The user closed the popup — this is normal, never show an error.
  cancelled,

  /// Google or Firebase rejected the request (usually an unregistered origin).
  configuration,

  /// Credentials invalid / account disabled.
  credentials,

  /// Rate limit or quota.
  throttled,

  /// Network unreachable.
  network,

  /// The browser blocked the popup window.
  popupBlocked,

  /// Anything else.
  unknown,
}

/// Turns a raw auth exception into a user-facing message and a UI hint.
class GoogleAuthDiagnosis {
  final GoogleAuthOutcome outcome;

  /// Short, human-readable Indonesian explanation.
  final String message;

  /// True when [GoogleAuthConfig.webSetupSteps] should be surfaced.
  final bool showSetupSteps;

  const GoogleAuthDiagnosis({
    required this.outcome,
    required this.message,
    this.showSetupSteps = false,
  });

  bool get isCancelled => outcome == GoogleAuthOutcome.cancelled;

  /// Classifies a raw exception thrown by `google_sign_in` or `firebase_auth`.
  factory GoogleAuthDiagnosis.from(Object error) {
    final code = error.toString().toLowerCase();

    // Closing the popup is an expected user action, never an error banner.
    if (code.contains('popup-closed-by-user') ||
        code.contains('popup_closed') ||
        code.contains('user-cancelled') ||
        code.contains('user_cancelled') ||
        code.contains('canceled') ||
        code.contains('cancelled') ||
        code.contains('12501')) {
      return const GoogleAuthDiagnosis(
        outcome: GoogleAuthOutcome.cancelled,
        message: 'Login Google dibatalkan.',
      );
    }

    // Content blockers and aggressive popup settings.
    if (code.contains('popup-blocked') ||
        code.contains('popup_blocked') ||
        code.contains('blockedbyclient') ||
        code.contains('aborted') && code.contains('popup')) {
      return const GoogleAuthDiagnosis(
        outcome: GoogleAuthOutcome.popupBlocked,
        message:
            'Popup diblokir browser. Izinkan pop-up untuk situs ini, lalu coba lagi.',
      );
    }

    // Firebase rejects unknown origins before OAuth even starts.
    if (code.contains('unauthorized-domain') ||
        code.contains('unauthorized_domain') ||
        code.contains('origin_mismatch') ||
        code.contains('redirect_uri_mismatch')) {
      return const GoogleAuthDiagnosis(
        outcome: GoogleAuthOutcome.configuration,
        message: GoogleAuthConfig.webOriginHelp,
        showSetupSteps: true,
      );
    }

    if (code.contains('api key not valid') ||
        code.contains('invalid_client') ||
        code.contains('unauthorized_client') ||
        code.contains('invalid-credential') ||
        code.contains('invalid_credential') ||
        code.contains('401')) {
      // `invalid-credential` dari Firebase hampir selalu berarti ID token
      // yang dikirim bukan dari Web client yang benar (salah serverClientId),
      // atau SHA-1 debug/release belum terdaftar di Firebase Console.
      return const GoogleAuthDiagnosis(
        outcome: GoogleAuthOutcome.configuration,
        message:
            'Login Google ditolak Firebase (invalid-credential). Penyebab umum: '
            'SHA-1 belum terdaftar di Firebase Console → Project settings, atau '
            'serverClientId bukan Web client. Lihat langkah di bawah.',
        showSetupSteps: true,
      );
    }

    // Android: ApiException 10 / DEVELOPER_ERROR = SHA-1 / package name
    // belum terdaftar, atau google-services.json tidak cocok.
    if (code.contains('apierror: 10') ||
        code.contains('apiexception: 10') ||
        code.contains('code: 10') ||
        code.contains('statuscode: 10') ||
        code.contains('developer_error') ||
        code.contains('sign_in_failed')) {
      return const GoogleAuthDiagnosis(
        outcome: GoogleAuthOutcome.configuration,
        message:
            'Google Sign-In gagal di perangkat (DEVELOPER_ERROR / code 10). '
            'SHA-1 fingerprint atau package name belum terdaftar di Firebase '
            'Console → Project settings → aplikasi Android ini.',
        showSetupSteps: true,
      );
    }

    if (code.contains('quota') ||
        code.contains('429') ||
        code.contains('too_many_requests')) {
      return const GoogleAuthDiagnosis(
        outcome: GoogleAuthOutcome.throttled,
        message: 'Terlalu banyak percobaan login. Coba lagi beberapa saat.',
      );
    }

    if (code.contains('network') ||
        code.contains('failed to fetch') ||
        code.contains('socket')) {
      return const GoogleAuthDiagnosis(
        outcome: GoogleAuthOutcome.network,
        message: 'Tidak ada koneksi internet. Periksa jaringanmu lalu coba lagi.',
      );
    }

    return const GoogleAuthDiagnosis(
      outcome: GoogleAuthOutcome.unknown,
      message: 'Login Google gagal. Silakan coba lagi.',
    );
  }
}
