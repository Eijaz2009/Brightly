import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'facebook_auth_config.dart';
import 'google_auth_config.dart';

class AuthResult {
  final bool success;
  final String? error;
  final String role;
  final bool isBlocked;
  final bool isCancelled;

  /// Set for Google sign-in so the UI can distinguish "user cancelled" (silent)
  /// from "misconfigured OAuth" (show setup steps).
  final GoogleAuthDiagnosis? googleDiagnosis;

  /// Set for Facebook sign-in.
  final FacebookAuthDiagnosis? facebookDiagnosis;

  const AuthResult({
    required this.success,
    this.error,
    this.role = 'user',
    this.isBlocked = false,
    this.isCancelled = false,
    this.googleDiagnosis,
    this.facebookDiagnosis,
  });

  /// True when the user simply closed the popup/flow — no error UI should appear.
  bool get wasCancelled =>
      isCancelled ||
      (googleDiagnosis?.isCancelled ?? false) ||
      (facebookDiagnosis?.isCancelled ?? false);
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static bool get isLoggedIn => _auth.currentUser != null;

  /// `FirebaseAuth.instance` throws when Firebase has not finished
  /// initialising (cold start, widget tests, tooling). UI code must never be
  /// able to crash on that, so reads are guarded.
  static User? safeCurrentUser() {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  static String displayName([User? user]) {
    user ??= safeCurrentUser();
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'Teman';
  }

  /// Validate email format
  static String? validateEmail(String email) {
    final value = email.trim();
    if (value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
    if (!emailRegex.hasMatch(value)) return 'Please enter a valid email address';
    return null;
  }

  /// Validate password strength
  static String? validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  /// Get user role and blocked status from Firestore
  static Future<Map<String, dynamic>> _getUserMeta(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 3));
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return <String, dynamic>{
          // Normalised to lower case — the admin UI used to write 'Admin'
          // while the rest of the app compared against 'admin'.
          'role': (data['role'] ?? 'user').toString().toLowerCase(),
          'blocked': data['blocked'] == true,
          'nama': data['nama'] ?? data['name'] ?? 'User',
          'exists': true,
        };
      }
    } catch (e) {
      debugPrint('Error fetching user meta (fallback to user): $e');
    }
    return <String, dynamic>{
      'role': 'user',
      'blocked': false,
      'nama': 'User',
      'exists': false,
    };
  }

  /// Sign in with email and password
  static Future<AuthResult> signInWithEmail(String email, String password) async {
    // Validate inputs
    final emailError = validateEmail(email);
    if (emailError != null) return AuthResult(success: false, error: emailError);

    final passwordError = validatePassword(password);
    if (passwordError != null) return AuthResult(success: false, error: passwordError);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        return const AuthResult(success: false, error: 'Login failed. Please try again.');
      }

      // Check blocked status and get role
      final meta = await _getUserMeta(credential.user!.uid);
      
      if (meta['blocked'] == true) {
        await _auth.signOut();
        return const AuthResult(
          success: false,
          error: 'Your account has been suspended. Please contact support.',
          isBlocked: true,
        );
      }

      return AuthResult(
        success: true,
        role: meta['role'] ?? 'user',
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;
        default:
          message = 'Login failed: ${e.message}';
      }
      return AuthResult(success: false, error: message);
    } catch (e) {
      return const AuthResult(success: false, error: 'An unexpected error occurred. Please try again.');
    }
  }

  /// Sign in with Google.
  ///
  /// The two platforms need different flows.
  ///
  /// **Web** uses `signInWithPopup(GoogleAuthProvider())`. The Firebase JS SDK
  /// redirects through the project's `authDomain`
  /// (`…firebaseapp.com/__/auth/handler`), which is already a registered
  /// `redirect_uri`, so no OAuth client id is needed in Dart.
  ///
  /// This replaced the `google_sign_in` web path, which sent
  /// `redirect_uri=http://localhost:<port>` and therefore failed with
  /// `Error 400: redirect_uri_mismatch` on every origin. Probing Google's
  /// `accounts:createAuthUri` confirms why: that request shape is rejected,
  /// while the `authDomain` handler shape returns the real sign-in page.
  /// Registering `http://localhost` as an authorized *origin* cannot fix it —
  /// origin and `redirect_uri` are validated separately.
  ///
  /// **Android/iOS** keeps `google_sign_in`, which returns a real credential
  /// and needs the platform `serverClientId`.
  static Future<AuthResult> signInWithGoogle() async {
    if (kIsWeb) return _signInWithGoogleWeb();
    return _signInWithGoogleNative();
  }

  /// Web path: Firebase-hosted popup, so no OAuth client id is required.
  static Future<AuthResult> _signInWithGoogleWeb() async {
    try {
      final provider = GoogleAuthProvider();

      UserCredential userCredential;
      try {
        userCredential = await _auth.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'popup-blocked') rethrow;

        debugPrint('Popup diblokir browser, beralih ke redirect.');
        await _auth.signInWithRedirect(provider);
        return const AuthResult(
          success: false,
          error: 'Mengarahkan ke login Google...',
        );
      }

      final user = userCredential.user;
      if (user == null) return _cancelled;

      return _finaliseGoogleUser(user);
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase auth error: ${e.code} ${e.message}');
      if (e.code == 'popup-closed-by-user' || e.code == 'user-cancelled') {
        return _cancelled;
      }
      final diagnosis = GoogleAuthDiagnosis.from(e);
      return AuthResult(
        success: false,
        error: diagnosis.message,
        googleDiagnosis: diagnosis,
      );
    } catch (e) {
      final diagnosis = GoogleAuthDiagnosis.from(e);
      debugPrint('Google sign-in diagnosis: ${diagnosis.outcome} — $e');
      return AuthResult(
        success: false,
        error: diagnosis.message,
        googleDiagnosis: diagnosis,
      );
    }
  }

  /// Native path: `google_sign_in` credential exchange.
  static Future<AuthResult> _signInWithGoogleNative() async {
    return _attemptGoogleSignInNative(GoogleAuthConfig.serverClientId);
  }

  static Future<AuthResult> _attemptGoogleSignInNative(
    String serverClientId, {
    bool isFallback = false,
  }) async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: serverClientId,
      );
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return _cancelled;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        debugPrint('Google Sign-In: idToken & accessToken null with $serverClientId');
        if (!isFallback &&
            GoogleAuthConfig.fallbackServerClientId.isNotEmpty &&
            GoogleAuthConfig.fallbackServerClientId != serverClientId) {
          debugPrint('Retrying with fallback serverClientId...');
          return _attemptGoogleSignInNative(
            GoogleAuthConfig.fallbackServerClientId,
            isFallback: true,
          );
        }
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return _cancelled;

      return _finaliseGoogleUser(user);
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase auth error: ${e.code} ${e.message}');
      if (!isFallback &&
          (e.code == 'invalid-credential' || e.code == 'invalid-verification-id') &&
          GoogleAuthConfig.fallbackServerClientId.isNotEmpty &&
          GoogleAuthConfig.fallbackServerClientId != serverClientId) {
        debugPrint('invalid-credential encountered, retrying with fallback serverClientId...');
        return _attemptGoogleSignInNative(
          GoogleAuthConfig.fallbackServerClientId,
          isFallback: true,
        );
      }
      final diagnosis = GoogleAuthDiagnosis.from(e);
      return AuthResult(
        success: false,
        error: diagnosis.message,
        googleDiagnosis: diagnosis,
      );
    } catch (e) {
      final diagnosis = GoogleAuthDiagnosis.from(e);
      debugPrint('Google sign-in diagnosis: ${diagnosis.outcome} — $e');

      if (diagnosis.outcome == GoogleAuthOutcome.configuration) {
        debugPrint('Google native auth configuration issue, attempting provider flow fallback...');
        try {
          final userCredential = await _auth.signInWithProvider(GoogleAuthProvider());
          final user = userCredential.user;
          if (user == null) return _cancelled;
          return _finaliseGoogleUser(user);
        } on FirebaseAuthException catch (fbError) {
          if (fbError.code == 'popup-closed-by-user' ||
              fbError.code == 'user-cancelled' ||
              fbError.code == 'web-context-cancelled') {
            return _cancelled;
          }
          debugPrint('Google fallback provider auth error: ${fbError.code} ${fbError.message}');
        } catch (fallbackError) {
          debugPrint('Google fallback provider unexpected error: $fallbackError');
        }
      }

      return AuthResult(
        success: false,
        error: diagnosis.message,
        googleDiagnosis: diagnosis,
      );
    }
  }

  static const AuthResult _cancelled = AuthResult(
    success: false,
    isCancelled: true,
    error: 'Google Sign-In was cancelled.',
    googleDiagnosis: GoogleAuthDiagnosis(
      outcome: GoogleAuthOutcome.cancelled,
      message: 'Login Google dibatalkan.',
    ),
  );

  /// Sign in with Facebook.
  static Future<AuthResult> signInWithFacebook() async {
    try {
      if (!kIsWeb) {
        // Native Android / iOS via flutter_facebook_auth
        final LoginResult loginResult = await FacebookAuth.instance.login(
          permissions: const ['email', 'public_profile'],
        );

        if (loginResult.status == LoginStatus.success && loginResult.accessToken != null) {
          final OAuthCredential credential = FacebookAuthProvider.credential(
            loginResult.accessToken!.tokenString,
          );
          final userCredential = await _auth.signInWithCredential(credential);
          final user = userCredential.user;
          if (user == null) {
            return const AuthResult(
              success: false,
              isCancelled: true,
              error: 'Login Facebook dibatalkan.',
            );
          }
          return _finaliseSocialUser(user, 'Facebook User');
        }

        if (loginResult.status == LoginStatus.cancelled) {
          return const AuthResult(
            success: false,
            isCancelled: true,
            error: 'Login Facebook dibatalkan.',
          );
        }

        final errorMsg = loginResult.message ?? 'Login Facebook gagal.';
        debugPrint('Facebook SDK login status: ${loginResult.status}, error: $errorMsg');
        final diagnosis = FacebookAuthDiagnosis.from(errorMsg);
        return AuthResult(
          success: false,
          error: diagnosis.message,
          facebookDiagnosis: diagnosis,
        );
      }

      final provider = OAuthProvider('facebook.com');
      provider.addScope('email');
      provider.addScope('public_profile');
      provider.setCustomParameters({'display': 'popup'});

      UserCredential userCredential;
      try {
        userCredential = await _auth.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-blocked') {
          await _auth.signInWithRedirect(provider);
          return const AuthResult(
            success: false,
            error: 'Mengarahkan ke login Facebook...',
          );
        }
        rethrow;
      }

      final user = userCredential.user;
      if (user == null) {
        return const AuthResult(
          success: false,
          isCancelled: true,
          error: 'Login Facebook dibatalkan.',
        );
      }

      return _finaliseSocialUser(user, 'Facebook User');
    } on FirebaseAuthException catch (e) {
      debugPrint('Facebook auth error: ${e.code} ${e.message}');
      final diagnosis = FacebookAuthDiagnosis.from(e);
      if (diagnosis.isCancelled) {
        return AuthResult(
          success: false,
          isCancelled: true,
          error: 'Login Facebook dibatalkan.',
          facebookDiagnosis: diagnosis,
        );
      }
      return AuthResult(
        success: false,
        error: diagnosis.message,
        facebookDiagnosis: diagnosis,
      );
    } catch (e) {
      debugPrint('Facebook sign-in error: $e');
      final diagnosis = FacebookAuthDiagnosis.from(e);
      if (diagnosis.isCancelled) {
        return AuthResult(
          success: false,
          isCancelled: true,
          error: 'Login Facebook dibatalkan.',
          facebookDiagnosis: diagnosis,
        );
      }
      return AuthResult(
        success: false,
        error: diagnosis.message,
        facebookDiagnosis: diagnosis,
      );
    }
  }

  /// Finalize social sign-in user (shared for Google/Facebook).
  static Future<AuthResult> _finaliseGoogleUser(User user) async {
    return _finaliseSocialUser(user, 'Google User');
  }

  static Future<AuthResult> _finaliseSocialUser(User user, String defaultName) async {
    final meta = await _getUserMeta(user.uid);

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(<String, dynamic>{
            'nama': user.displayName ?? defaultName,
            'name': user.displayName ?? defaultName,
            'email': user.email ?? '',
            if (!meta['exists']) 'role': 'user',
            'lastLoginAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Social profile upsert failed (login still succeeds): $e');
    }

    if (meta['blocked'] == true) {
      await _auth.signOut();
      return const AuthResult(
        success: false,
        error: 'Your account has been suspended. Please contact support.',
        isBlocked: true,
      );
    }

    return AuthResult(success: true, role: meta['role'] ?? 'user');
  }

  /// Register with email and password
  static Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (name.trim().isEmpty) {
      return const AuthResult(success: false, error: 'Name is required');
    }

    final emailError = validateEmail(email);
    if (emailError != null) return AuthResult(success: false, error: emailError);

    final passwordError = validatePassword(password);
    if (passwordError != null) {
      return AuthResult(success: false, error: passwordError);
    }

    if (password != confirmPassword) {
      return const AuthResult(
        success: false,
        error: 'Passwords do not match',
      );
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name.trim());
        await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
          'nama': name.trim(),
          'name': name.trim(),
          'email': email.trim(),
          'role': 'user',
          'blocked': false,
          'bookmarks': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Sign out so the user logs in explicitly after registering.
      await _auth.signOut();

      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'weak-password' =>
          'The password is too weak. Use at least 6 characters.',
        'email-already-in-use' =>
          'An account already exists with this email.',
        'invalid-email' => 'The email address is invalid.',
        'operation-not-allowed' =>
          'Email/password sign-in is disabled in the Firebase console.',
        _ => 'Registration failed: ${e.message}',
      };
      return AuthResult(success: false, error: message);
    } catch (e) {
      debugPrint('Register error: $e');
      return const AuthResult(
        success: false,
        error: 'Registration failed. Please try again.',
      );
    }
  }

  /// Kirim tautan reset via email. Dibuat anti-error:
  /// - Tanpa query Firestore dulu (aturan `users` menolak baca logged-out,
  ///   jadi pre-flight hanya menambah gagal + delay).
  /// - Tanpa ActionCodeSettings (pakai authDomain bawaan → bebas
  ///   unauthorized-continue-uri).
  /// - Timeout 20 detik agar tidak menggantung.
  /// - Email tak terdaftar → SUKSES generik (anti-enumerasi Firebase),
  ///   jadi tidak ada popup merah hanya karena salah ketik.
  /// - Semua error Firebase dipetakan ke Bahasa Indonesia yang jelas.
  static Future<AuthResult> sendPasswordReset(String email) async {
    final emailError = validateEmail(email);
    if (emailError != null) {
      // Samakan ke Bahasa Indonesia agar konsisten dengan layar lain.
      if (emailError == 'Email is required') {
        return const AuthResult(
          success: false,
          error: 'Email wajib diisi.',
        );
      }
      return const AuthResult(
        success: false,
        error: 'Format email tidak valid. Contoh: nama@email.com',
      );
    }

    final clean = email.trim();

    try {
      await _auth
          .sendPasswordResetEmail(email: clean)
          .timeout(const Duration(seconds: 20));
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      debugPrint('sendPasswordReset [${e.code}]: ${e.message}');
      switch (e.code) {
        case 'invalid-email':
        case 'missing-email':
          return const AuthResult(
            success: false,
            error: 'Format email tidak valid. Contoh: nama@email.com',
          );
        case 'user-not-found':
        case 'invalid-credential':
        case 'invalid-login-credentials':
        case 'user-mismatch':
        case 'wrong-password':
          // Proteksi enumerasi Firebase: jangan bocorkan akun ada/tidak.
          return const AuthResult(success: true);
        case 'too-many-requests':
          return const AuthResult(
            success: false,
            error: 'Terlalu banyak percobaan. Tunggu 5–10 menit lalu coba lagi.',
          );
        case 'network-request-failed':
          return const AuthResult(
            success: false,
            error: 'Tidak ada koneksi internet. Periksa jaringanmu lalu coba lagi.',
          );
        case 'operation-not-allowed':
          return const AuthResult(
            success: false,
            error: 'Reset via email belum aktif. Aktifkan di Firebase Console → '
                'Authentication → Sign-in method → Email/Password.',
          );
        case 'missing-android-pkg-name':
        case 'missing-continue-uri':
        case 'missing-ios-bundle-id':
        case 'invalid-continue-uri':
        case 'unauthorized-continue-uri':
          return AuthResult(
            success: false,
            error: 'Konfigurasi tautan reset bermasalah (${e.code}). '
                'Coba lagi tanpa menutup aplikasi, atau gunakan OTP SMS.',
          );
        case 'unknown':
        case 'internal-error':
          return AuthResult(
            success: false,
            error: 'Server auth sibuk (${e.code}). Tunggu sebentar lalu coba lagi.',
          );
        default:
          final detail = (e.message ?? '').trim();
          // Jangan tampilkan pesan Inggris mentah kalau kosong/teknis.
          if (detail.isEmpty || detail.startsWith('[')) {
            return const AuthResult(
              success: false,
              error: 'Gagal mengirim email reset. Coba lagi atau gunakan OTP SMS.',
            );
          }
          return AuthResult(
            success: false,
            error: 'Gagal mengirim email reset: $detail',
          );
      }
    } on FirebaseException catch (e) {
      debugPrint('sendPasswordReset Firebase [${e.code}]: ${e.message}');
      if (e.code == 'network-request-failed') {
        return const AuthResult(
          success: false,
          error: 'Tidak ada koneksi internet. Periksa jaringanmu lalu coba lagi.',
        );
      }
      return AuthResult(
        success: false,
        error: 'Gagal mengirim email reset (${e.code}). Coba lagi.',
      );
    } on TimeoutException {
      return const AuthResult(
        success: false,
        error: 'Permintaan timeout. Periksa koneksi lalu coba lagi.',
      );
    } catch (e) {
      debugPrint('sendPasswordReset error: $e');
      return const AuthResult(
        success: false,
        error: 'Gagal mengirim email reset. Silakan coba lagi.',
      );
    }
  }

  /// Completes a `signInWithRedirect` round-trip on web.
  ///
  /// The popup fallback in [_signInWithGoogleWeb] navigates the whole tab away
  /// to Google, so the app restarts afterwards and the credential is waiting in
  /// the URL. Without this call the user lands back on the login screen already
  /// signed in but never routed into the app — the fallback silently dead-ends.
  ///
  /// Safe to call on every platform and on every launch: it resolves to null
  /// when there is no pending redirect.
  static Future<AuthResult?> completeRedirectSignIn() async {
    if (!kIsWeb) return null;

    try {
      final result = await _auth.getRedirectResult();
      final user = result.user;
      if (user == null) return null;
      return _finaliseGoogleUser(user);
    } catch (e) {
      debugPrint('Redirect sign-in result: $e');
      final diagnosis = GoogleAuthDiagnosis.from(e);
      // A cancelled redirect must not surface as an error on a normal launch.
      if (diagnosis.isCancelled) return null;
      return AuthResult(
        success: false,
        error: diagnosis.message,
        googleDiagnosis: diagnosis,
      );
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Check if current user is admin
  static Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final meta = await _getUserMeta(user.uid);
    return meta['role'] == 'admin';
  }  /// Check if current user is blocked
  static Future<bool> isCurrentUserBlocked() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final meta = await _getUserMeta(user.uid);
    return meta['blocked'] == true;
  }

  /// Get system config from Firestore
  static Future<Map<String, dynamic>> getSystemConfig() async {
    try {
      final doc = await _firestore.collection('config').doc('system').get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching system config: $e');
    }
    return {};
  }
}
