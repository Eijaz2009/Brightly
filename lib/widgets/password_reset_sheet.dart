import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show PhoneAuthCredential;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_style.dart';
import '../services/auth_service.dart';
import '../services/phone_auth_service.dart';

/// Alur "Lupa password" 3 langkah berbasis OTP SMS (Firebase Phone Auth):
///
/// 1. Masukkan nomor HP → Firebase mengirim 6 digit OTP.
/// 2. Masukkan OTP → masuk sementara ke akun yang nomornya tertaut.
/// 3. Buat password baru → sesi di-sign-out, user masuk ulang.
///
/// Tidak ada OTP tanpa server SMTP: pengiriman SMS ditangani Firebase.
/// Syaratnya: nomor HARUS sudah ditautkan dari menu Profil, dan provider
/// Phone sudah di-enable di Firebase Console.
///
/// Link reset via email bawaan tetap tersedia sebagai cadangan (opsi
/// "Kirim tautan email" di langkah 1).
Future<void> showPasswordResetFlow(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _PasswordResetSheet(),
  );
}

enum _Step { phone, otp, newPassword }

class _PasswordResetSheet extends StatefulWidget {
  const _PasswordResetSheet();

  @override
  State<_PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<_PasswordResetSheet> {
  _Step _step = _Step.phone;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String? _verificationId;
  int? _resendToken;
  bool _isLoading = false;
  bool _isResending = false;

  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _toast(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  String get _normalizedPhone =>
      PhoneAuthService.normalizePhone(_phoneController.text) ?? '';

  /// Langkah 1 → kirim OTP ke nomor HP.
  Future<void> _sendOtp({bool resend = false}) async {
    final error = PhoneAuthService.validatePhone(_phoneController.text);
    if (error != null) {
      _toast(error, AppStyle.danger);
      return;
    }

    if (resend) {
      setState(() => _isResending = true);
    } else {
      setState(() => _isLoading = true);
    }

    await PhoneAuthService.sendVerificationCode(
      phoneNumber: _normalizedPhone,
      forceResendingToken: resend ? _resendToken : null,
      // Android kadang memverifikasi otomatis tanpa OTP manual.
      onAutoVerified: (credential) async {
        if (!mounted) return;
        await _finishPhoneSignIn(credential);
      },
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isLoading = false;
          _isResending = false;
          _step = _Step.otp;
        });
        _startCooldown();
        _toast(
          'Kode OTP dikirim ke $_normalizedPhone',
          AppStyle.mint,
        );
      },
      onFailed: (message) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isResending = false;
        });
        _toast(message, AppStyle.danger);
      },
      onAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// Masuk sementara memakai kredensial HP (auto-verify maupun OTP manual).
  Future<void> _finishPhoneSignIn(PhoneAuthCredential credential) async {
    final result = await PhoneAuthService.signInWithCredential(credential);
    if (!mounted) return;
    if (result.success) {
      setState(() => _step = _Step.newPassword);
      return;
    }
    setState(() => _isLoading = false);
    _toast(result.error ?? 'Verifikasi gagal.', AppStyle.danger);
  }

  /// Langkah 2 → verifikasi 6 digit kode.
  Future<void> _confirmOtp() async {
    if (_verificationId == null) {
      _toast('Kirim ulang kode OTP terlebih dahulu.', AppStyle.danger);
      return;
    }
    setState(() => _isLoading = true);
    final result = await PhoneAuthService.confirmCodeAndSignIn(
      verificationId: _verificationId!,
      smsCode: _otpController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      _otpController.clear();
      setState(() => _step = _Step.newPassword);
      return;
    }
    _toast(result.error ?? 'Verifikasi gagal.', AppStyle.danger);
  }

  /// Langkah 3 → simpan password baru, lalu tutup dan suruh login ulang.
  Future<void> _saveNewPassword() async {
    setState(() => _isLoading = true);
    final result = await PhoneAuthService.updatePassword(
      password: _passwordController.text,
      confirm: _confirmController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      Navigator.pop(context);
      _toast(
        'Password berhasil diganti. Silakan masuk dengan password baru.',
        AppStyle.mint,
      );
      return;
    }
    _toast(result.error ?? 'Gagal menyimpan password.', AppStyle.danger);
  }

  /// Cadangan: kirim tautan reset via email bawaan Firebase.
  /// Dibuat anti-error: loading di dialog (bukan di sheet), tombol
  /// nonaktif saat mengirim, dan pesan sukses generik anti-enumerasi.
  Future<void> _sendEmailLink() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool sending = false;
    String? errorText;

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            if (sending) return;
            if (!(formKey.currentState?.validate() ?? false)) return;
            setDialogState(() {
              sending = true;
              errorText = null;
            });
            final result = await AuthService.sendPasswordReset(
              emailController.text,
            );
            if (!ctx.mounted) return;
            if (result.success) {
              Navigator.pop(ctx, emailController.text.trim());
              return;
            }
            setDialogState(() {
              sending = false;
              errorText = result.error ?? 'Gagal mengirim email reset.';
            });
          }

          return AlertDialog(
            title: const Text('Kirim tautan email'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masukkan email akunmu. Kalau terdaftar, kami kirim tautan reset.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    enabled: !sending,
                    decoration: const InputDecoration(
                      hintText: 'Alamat email',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email wajib diisi.';
                      }
                      if (AuthService.validateEmail(value) != null) {
                        return 'Format email tidak valid.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => submit(),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: AppStyle.danger,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            errorText!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              height: 1.45,
                              color: AppStyle.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    sending ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: sending ? null : submit,
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kirim tautan'),
              ),
            ],
          );
        },
      ),
    );
    emailController.dispose();
    if (email == null || email.isEmpty || !mounted) return;

    _toast(
      'Kalau email $email terdaftar, tautan reset sudah dikirim. '
      'Cek kotak masuk & folder spam.',
      AppStyle.mint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppStyle.getCardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppStyle.getBorderColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppStyle.spark.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.sms_outlined,
                      color: AppStyle.spark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lupa password',
                          style: AppStyle.font(
                            context,
                            size: 18,
                            weight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Verifikasi OTP lalu buat password baru.',
                          style: AppStyle.font(
                            context,
                            size: 12.5,
                            weight: FontWeight.w500,
                            color: AppStyle.getSubtitleColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StepIndicator(step: _step),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: switch (_step) {
                  _Step.phone => _buildPhoneStep(),
                  _Step.otp => _buildOtpStep(),
                  _Step.newPassword => _buildNewPasswordStep(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nomor HP yang terhubung ke akunmu. Kami kirim 6 digit kode OTP via SMS.',
          style: _hintStyle(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: AppStyle.font(context, size: 14.5, weight: FontWeight.w600),
          decoration: const InputDecoration(
            hintText: '0812xxxxxxx',
            prefixIcon: Icon(Icons.phone_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 18),
        AppStyle.primaryButton(
          context: context,
          label: 'Kirim kode OTP',
          icon: Icons.send_rounded,
          loading: _isLoading,
          onPressed: _isLoading ? () {} : () => _sendOtp(),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _sendEmailLink,
            child: const Text('atau kirim tautan via email'),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppStyle.sunny.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppStyle.sunny,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Belum menautkan nomor HP? Buka Profil → tautkan nomor '
                  'saat masih bisa masuk, supaya OTP bisa dipakai nanti.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.5,
                    color: AppStyle.getSubtitleColor(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    final canResend = _cooldown == 0 && !_isResending;
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Masukkan 6 digit kode yang dikirim ke $_normalizedPhone.',
          style: _hintStyle(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: AppStyle.font(
            context,
            size: 24,
            weight: FontWeight.w800,
            spacing: 8,
          ),
          decoration: const InputDecoration(
            hintText: '••••••',
            counterText: '',
          ),
        ),
        const SizedBox(height: 18),
        AppStyle.primaryButton(
          context: context,
          label: 'Verifikasi kode',
          icon: Icons.verified_outlined,
          loading: _isLoading,
          onPressed: _isLoading ? () {} : _confirmOtp,
        ),
        const SizedBox(height: 10),
        Center(
          child: canResend
              ? TextButton(
                  onPressed: () => _sendOtp(resend: true),
                  child: const Text('Kirim ulang kode'),
                )
              : Text(
                  _isResending
                      ? 'Mengirim ulang…'
                      : 'Kirim ulang dalam $_cooldown dtk',
                  style: AppStyle.font(
                    context,
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: AppStyle.getSubtitleColor(context),
                  ),
                ),
        ),
        Center(
          child: TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() => _step = _Step.phone),
            child: const Text('Ganti nomor HP'),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      key: const ValueKey('password'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nomor terverifikasi. Buat password baru untuk akunmu.',
          style: _hintStyle(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          keyboardType: TextInputType.visiblePassword,
          style: AppStyle.font(context, size: 14.5, weight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Password baru (min. 6 karakter)',
            prefixIcon: const Icon(Icons.lock_rounded, size: 20),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 19,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmController,
          obscureText: _obscureConfirm,
          keyboardType: TextInputType.visiblePassword,
          style: AppStyle.font(context, size: 14.5, weight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Ulangi password baru',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 19,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        AppStyle.primaryButton(
          context: context,
          label: 'Simpan password baru',
          icon: Icons.check_circle_outline_rounded,
          loading: _isLoading,
          onPressed: _isLoading ? () {} : _saveNewPassword,
        ),
      ],
    );
  }

  TextStyle _hintStyle() {
    return AppStyle.font(
      context,
      size: 13,
      weight: FontWeight.w500,
      color: AppStyle.getSubtitleColor(context),
      height: 1.5,
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final _Step step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final index = _Step.values.indexOf(step);
    const labels = ['Nomor', 'OTP', 'Baru'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          _dot(context, i, index, labels[i]),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: i < index
                      ? AppStyle.mint
                      : AppStyle.getBorderColor(context),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _dot(BuildContext context, int i, int current, String label) {
    final done = i < current;
    final active = i == current;
    final color = done || active ? AppStyle.spark : Colors.transparent;
    final border = done || active
        ? AppStyle.spark
        : AppStyle.getBorderColor(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: done ? 1 : (active ? 0.15 : 0)),
            border: Border.all(color: border, width: 1.6),
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : Text(
                  '${i + 1}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? AppStyle.spark
                        : AppStyle.getSubtitleColor(context),
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppStyle.font(
            context,
            size: 11.5,
            weight: FontWeight.w700,
            color: done || active
                ? AppStyle.getTextColor(context)
                : AppStyle.getSubtitleColor(context),
          ),
        ),
      ],
    );
  }
}
