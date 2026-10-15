/// Facebook OAuth configuration and diagnosis for ScholarPath.
class FacebookAuthConfig {
  /// Steps required to configure Facebook Sign-in in Firebase Console and Meta Developers.
  static List<String> get setupSteps => const <String>[
    'Buka Meta for Developers (developers.facebook.com) dan buat Aplikasi Facebook',
    'Dapatkan App ID dan Client Token dari dashboard Meta',
    'Aktifkan provider "Facebook" di Firebase Console → Authentication → Sign-in method',
    'Tambahkan Facebook App ID ke AndroidManifest.xml & strings.xml',
    'Atau gunakan opsi masuk yang sudah siap: Login dengan Google atau Email/Password',
  ];
}

/// Turns a raw Facebook auth exception into a user-facing explanation and hints.
class FacebookAuthDiagnosis {
  final bool isCancelled;
  final bool showSetupSteps;
  final String message;

  const FacebookAuthDiagnosis({
    this.isCancelled = false,
    this.showSetupSteps = false,
    required this.message,
  });

  factory FacebookAuthDiagnosis.from(Object error) {
    final code = error.toString().toLowerCase();

    // User canceled the flow
    if (code.contains('popup-closed-by-user') ||
        code.contains('popup_closed') ||
        code.contains('user-cancelled') ||
        code.contains('user_cancelled') ||
        code.contains('web-context-cancelled') ||
        code.contains('canceled') ||
        code.contains('cancelled') ||
        code.contains('12501')) {
      return const FacebookAuthDiagnosis(
        isCancelled: true,
        message: 'Login Facebook dibatalkan.',
      );
    }

    // Provider disabled or not yet configured in Firebase Console
    if (code.contains('operation-not-allowed') ||
        code.contains('configuration-not-found') ||
        code.contains('provider-not-enabled')) {
      return const FacebookAuthDiagnosis(
        showSetupSteps: true,
        message:
            'Login Facebook belum diaktifkan di Firebase Console. '
            'Penyedia Facebook harus diaktifkan dan dikonfigurasi dengan App ID serta App Secret.',
      );
    }

    // Android: Firebase explicitly blocks generic OAuth for Facebook (TOS requires native SDK)
    if (code.contains('channel-error') ||
        code.contains('illegalargumentexception') ||
        code.contains('facebook tos') ||
        code.contains('facebook android sdk') ||
        code.contains('signinwithprovider')) {
      return const FacebookAuthDiagnosis(
        showSetupSteps: true,
        message:
            'Login Facebook di Android memerlukan pendaftaran App ID di Meta for Developers serta konfigurasi SDK resmi. '
            'Lihat langkah setup di bawah ini.',
      );
    }

    if (code.contains('account-exists-with-different-credential')) {
      return const FacebookAuthDiagnosis(
        message:
            'Akun dengan email ini sudah terdaftar menggunakan metode lain. '
            'Silakan masuk menggunakan Google atau Email/Password.',
      );
    }

    if (code.contains('popup-blocked') || code.contains('popup_blocked')) {
      return const FacebookAuthDiagnosis(
        message:
            'Popup diblokir oleh browser. Izinkan pop-up untuk situs ini lalu coba lagi.',
      );
    }

    if (code.contains('network') ||
        code.contains('failed to fetch') ||
        code.contains('socket')) {
      return const FacebookAuthDiagnosis(
        message:
            'Tidak ada koneksi internet. Periksa koneksi Anda lalu coba lagi.',
      );
    }

    return const FacebookAuthDiagnosis(
      message: 'Login Facebook gagal. Silakan coba lagi.',
    );
  }
}
