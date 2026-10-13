import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Hasil operasi phone-auth yang ramah UI.
class PhoneAuthResult {
  final bool success;
  final String? error;

  const PhoneAuthResult({required this.success, this.error});

  static const ok = PhoneAuthResult(success: true);

  factory PhoneAuthResult.fail(String error) =>
      PhoneAuthResult(success: false, error: error);
}

/// Reset password via OTP SMS memakai Firebase Phone Auth.
///
/// Tidak butuh server/SMTP tambahan. Cara kerjanya:
///
/// 1. User menautkan nomor HP ke akunnya dari menu Profil (lihat
///    [linkCredential]) — satu kali saja.
/// 2. Saat lupa password, user memasukkan nomor HP → Firebase mengirim OTP.
/// 3. OTP benar → Firebase masuk ke akun yang nomornya tertaut.
/// 4. User membuat password baru lewat [updatePassword].
///
/// Firebase tidak mengizinkan client mengganti password akun lain, jadi nomor
/// HARUS tertaut dulu. Kalau belum tertaut, [signInWithCredential] menolak
/// dengan pesan yang jelas (bukan error generik).
///
/// Syarat di Firebase Console:
/// - Authentication → Sign-in method → **Phone** harus di-enable.
/// - Untuk Android real-device: SHA-256 terdaftar (Play Integrity).
/// - Untuk testing tanpa SMS asli: daftarkan nomor + kode uji di
///   Authentication → Sign-in method → Phone
///   (mis. `+62 812 3456 7890` dengan kode `123456`).
class PhoneAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Normalisasi ke E.164 Indonesia (`+62...`). Null bila format tidak valid.
  static String? normalizePhone(String raw) {
    var p = raw.trim().replaceAll(RegExp(r'[\s\-().]'), '');
    if (p.isEmpty) return null;
    if (p.startsWith('+')) {
      // Biarkan apa adanya, divalidasi di bawah.
    } else if (p.startsWith('62')) {
      p = '+$p';
    } else if (p.startsWith('0')) {
      p = '+62${p.substring(1)}';
    } else if (RegExp(r'^\d+$').hasMatch(p)) {
      p = '+62$p';
    } else {
      return null;
    }
    if (!RegExp(r'^\+\d{9,15}$').hasMatch(p)) return null;
    return p;
  }

  static String? validatePhone(String raw) {
    if (raw.trim().isEmpty) return 'Nomor HP wajib diisi.';
    if (normalizePhone(raw) == null) {
      return 'Format nomor HP tidak valid. Contoh: 081234567890.';
    }
    return null;
  }

  static String? validateNewPassword(String password, String confirm) {
    if (password.length < 6) return 'Password minimal 6 karakter.';
    if (password != confirm) return 'Konfirmasi password tidak cocok.';
    return null;
  }

  /// Mengirim kode OTP ke [phoneNumber] (format E.164, mis. `+62812...`).
  ///
  /// Di Android, OTP kadang terverifikasi otomatis (auto-retrieval) — kalau
  /// itu terjadi, [onAutoVerified] dipanggil dan langkah input OTP dilewati.
  static Future<void> sendVerificationCode({
    required String phoneNumber,
    int? forceResendingToken,
    required Future<void> Function(PhoneAuthCredential credential)
    onAutoVerified,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String message) onFailed,
    required void Function(String verificationId) onAutoRetrievalTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken,
        verificationCompleted: (credential) async {
          await onAutoVerified(credential);
        },
        verificationFailed: (e) {
          debugPrint('Phone verification failed: ${e.code} ${e.message}');
          onFailed(_translateSendError(e));
        },
        codeSent: (verificationId, resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          onAutoRetrievalTimeout(verificationId);
        },
      );
    } catch (e) {
      debugPrint('sendVerificationCode error: $e');
      onFailed('Gagal mengirim OTP. Periksa koneksi lalu coba lagi.');
    }
  }

  /// Masuk memakai kredensial HP (hasil auto-verifikasi atau kode manual).
  ///
  /// Berhasil HANYA bila nomor tertaut ke akun ber-password (akun email).
  /// Nomor asing / akun Google-only ditolak dengan pesan yang jelas, dan sesi
  /// langsung di-sign-out supaya tidak ada akun nyasar yang tertinggal login.
  static Future<PhoneAuthResult> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        return PhoneAuthResult.fail('Verifikasi gagal. Silakan coba lagi.');
      }

      final hasPasswordProvider = user.providerData.any(
        (p) => p.providerId == 'password',
      );
      if (hasPasswordProvider) return PhoneAuthResult.ok;

      // Bukan akun email: nomor baru (belum tertaut ke siapa pun) atau akun
      // Google-only (tidak punya password untuk diganti).
      final hasProfile = await _profileExists(user.uid);
      await _auth.signOut();
      if (!hasProfile) {
        return PhoneAuthResult.fail(
          'Nomor ini belum terhubung ke akun manapun. Tautkan dulu dari '
          'menu Profil saat masih bisa masuk, atau gunakan tautan email.',
        );
      }
      return PhoneAuthResult.fail(
        'Akun ini masuk dengan Google dan belum punya password. '
        'Silakan masuk dengan Google.',
      );
    } on FirebaseAuthException catch (e) {
      return PhoneAuthResult.fail(_translateSignInError(e));
    } catch (e) {
      debugPrint('Phone sign-in error: $e');
      return PhoneAuthResult.fail('Verifikasi gagal. Silakan coba lagi.');
    }
  }

  /// Verifikasi 6 digit kode lalu masuk (dipakai langkah OTP manual).
  static Future<PhoneAuthResult> confirmCodeAndSignIn({
    required String verificationId,
    required String smsCode,
  }) async {
    if (smsCode.trim().length != 6) {
      return PhoneAuthResult.fail('Masukkan 6 digit kode OTP.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    return signInWithCredential(credential);
  }

  /// Menyimpan password baru. Wajib dipanggil setelah OTP terverifikasi
  /// (login masih fresh sehingga tidak kena `requires-recent-login`).
  /// Setelah sukses, sesi langsung di-sign-out agar user masuk ulang.
  static Future<PhoneAuthResult> updatePassword({
    required String password,
    required String confirm,
  }) async {
    final validationError = validateNewPassword(password, confirm);
    if (validationError != null) {
      return PhoneAuthResult.fail(validationError);
    }
    final user = _auth.currentUser;
    if (user == null) {
      return PhoneAuthResult.fail('Sesi verifikasi hilang. Ulangi dari awal.');
    }
    try {
      await user.updatePassword(password);
      await _auth.signOut();
      return PhoneAuthResult.ok;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'requires-recent-login':
          return PhoneAuthResult.fail(
            'Sesi kedaluwarsa. Ulangi verifikasi OTP dari awal.',
          );
        case 'weak-password':
          return PhoneAuthResult.fail(
            'Password terlalu lemah. Gunakan minimal 6 karakter.',
          );
        case 'network-request-failed':
          return PhoneAuthResult.fail(
            'Tidak ada koneksi internet. Periksa jaringanmu lalu coba lagi.',
          );
        default:
          return PhoneAuthResult.fail(
            'Gagal menyimpan password: ${e.message}',
          );
      }
    } catch (e) {
      debugPrint('updatePassword error: $e');
      return PhoneAuthResult.fail(
        'Gagal menyimpan password. Silakan coba lagi.',
      );
    }
  }

  /// Menautkan nomor HP ke akun yang sedang login (dipakai menu Profil).
  /// Nomor juga disimpan ke `users/{uid}.phone` sebagai penanda.
  static Future<PhoneAuthResult> linkCredential(
    PhoneAuthCredential credential, {
    required String phoneNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return PhoneAuthResult.fail('Sesi tidak ditemukan. Silakan masuk kembali.');
    }
    try {
      // Ganti nomor lama bila sudah ada yang tertaut.
      if ((user.phoneNumber ?? '').isNotEmpty) {
        try {
          await user.unlink(PhoneAuthProvider.PROVIDER_ID);
        } catch (_) {
          // Lanjutkan — `linkWithCredential` akan memberi tahu bila konflik.
        }
      }
      await user.linkWithCredential(credential);
      await _savePhone(user.uid, phoneNumber);
      return PhoneAuthResult.ok;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'provider-already-linked':
          await _savePhone(user.uid, phoneNumber);
          return PhoneAuthResult.ok;
        case 'credential-already-in-use':
          return PhoneAuthResult.fail('Nomor ini sudah dipakai akun lain.');
        case 'invalid-verification-code':
          return PhoneAuthResult.fail(
            'Kode OTP salah. Periksa SMS lalu coba lagi.',
          );
        case 'session-expired':
          return PhoneAuthResult.fail(
            'Kode OTP kedaluwarsa. Kirim ulang kodenya.',
          );
        default:
          return PhoneAuthResult.fail(
            'Gagal menautkan nomor: ${e.message}',
          );
      }
    } catch (e) {
      debugPrint('linkCredential error: $e');
      return PhoneAuthResult.fail('Gagal menautkan nomor. Silakan coba lagi.');
    }
  }

  /// Melepas tautan nomor HP dari akun yang sedang login.
  static Future<PhoneAuthResult> unlinkPhone() async {
    final user = _auth.currentUser;
    if (user == null) {
      return PhoneAuthResult.fail('Sesi tidak ditemukan. Silakan masuk kembali.');
    }
    try {
      if ((user.phoneNumber ?? '').isEmpty) return PhoneAuthResult.ok;
      await user.unlink(PhoneAuthProvider.PROVIDER_ID);
      await _firestore.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'phone': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return PhoneAuthResult.ok;
    } on FirebaseAuthException catch (e) {
      return PhoneAuthResult.fail('Gagal melepas nomor: ${e.message}');
    } catch (e) {
      debugPrint('unlinkPhone error: $e');
      return PhoneAuthResult.fail('Gagal melepas nomor. Silakan coba lagi.');
    }
  }

  static Future<void> _savePhone(String uid, String phone) async {
    try {
      await _firestore.collection('users').doc(uid).set(
        <String, dynamic>{
          'phone': phone,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      // Profil boleh gagal disimpan — tautan di Auth tetap valid.
      debugPrint('Save phone failed: $e');
    }
  }

  static Future<bool> _profileExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  static String _translateSendError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Nomor HP tidak valid. Gunakan format 08xxxxxxxxxx.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi.';
      case 'quota-exceeded':
        return 'Kuota SMS habis. Coba lagi besok atau gunakan tautan email.';
      case 'app-not-authorized':
        return 'Aplikasi tidak diotorisasi (SHA fingerprint belum terdaftar '
            'di Firebase Console → Project settings).';
      case 'missing-client-identifier':
      case 'captcha-check-failed':
        return 'Verifikasi keamanan gagal. Coba lagi (di web, pastikan tidak '
            'memblokir reCAPTCHA).';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet. Periksa jaringanmu lalu coba lagi.';
      default:
        return 'Gagal mengirim OTP (${e.code}). ${e.message ?? 'Coba lagi.'}';
    }
  }

  static String _translateSignInError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Kode OTP salah. Periksa SMS lalu coba lagi.';
      case 'session-expired':
        return 'Kode OTP kedaluwarsa. Kirim ulang kodenya.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet. Periksa jaringanmu lalu coba lagi.';
      default:
        return 'Verifikasi gagal (${e.code}). ${e.message ?? 'Coba lagi.'}';
    }
  }
}
