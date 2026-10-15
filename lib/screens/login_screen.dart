import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_style.dart';
import '../services/auth_service.dart';
import '../widgets/google_auth_setup_dialog.dart';
import '../widgets/password_reset_sheet.dart';
import 'admin_dashboard.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isFacebookLoading = false;
  bool _rememberMe = false;

  static const Color neonLime = Color(0xFFCEEB45);
  static const Color trueBlack = Color(0xFF121212);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color inputBorder = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_login_email');
      final remember = prefs.getBool('remember_me') ?? false;
      if (savedEmail != null && savedEmail.isNotEmpty && remember) {
        if (mounted) {
          setState(() {
            _emailController.text = savedEmail;
            _rememberMe = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _persistRememberMe(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_login_email', email);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_login_email');
        await prefs.setBool('remember_me', false);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Unfocus any active keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    final result = await AuthService.signInWithEmail(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      await _persistRememberMe(email);
      _route(result.role);
    } else {
      _showToast(result.error ?? 'Failed to sign in. Please check your credentials.', isError: true);
    }
  }

  void _route(String role) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            role == 'admin' ? const AdminDashboard() : const HomeScreen(),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final result = await AuthService.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    if (result.success) {
      _route(result.role);
      return;
    }

    if (result.wasCancelled) return;

    final diagnosis = result.googleDiagnosis;
    if (diagnosis != null && diagnosis.showSetupSteps) {
      await showGoogleAuthSetupDialog(
        context,
        reason: diagnosis.message,
        native: !kIsWeb,
      );
      return;
    }

    _showToast(
      result.error ?? 'Google sign-in was unsuccessful. Please try again.',
      isError: true,
    );
  }

  Future<void> _handleFacebookSignIn() async {
    setState(() => _isFacebookLoading = true);
    final result = await AuthService.signInWithFacebook();

    if (!mounted) return;
    setState(() => _isFacebookLoading = false);

    if (result.success) {
      _route(result.role);
      return;
    }

    if (result.wasCancelled) return;

    final diagnosis = result.facebookDiagnosis;
    if (diagnosis != null && diagnosis.showSetupSteps) {
      await showFacebookAuthSetupDialog(
        context,
        reason: diagnosis.message,
      );
      return;
    }

    _showToast(
      result.error ?? 'Facebook sign-in was unsuccessful. Please try again.',
      isError: true,
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    await showPasswordResetFlow(context);
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: isError ? Colors.white : trueBlack,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isError ? Colors.white : trueBlack,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppStyle.danger : neonLime,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top logo (only image, larger size, no border, no text)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Image.asset(
                        'assets/images/brightly_custom_logo.png',
                        height: 52,
                        width: 52,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.school_rounded,
                          size: 44,
                          color: trueBlack,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Header Title
                  Text(
                    'We Say Hello!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: trueBlack,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Sign in with your email and password to access your scholarship journey.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Email Input Field
                  _ModernFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    hint: 'Email Address',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      return AuthService.validateEmail(value.trim());
                    },
                    suffixWidget: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _emailController,
                      builder: (context, val, _) {
                        if (val.text.isEmpty) return const SizedBox.shrink();
                        return IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF9CA3AF)),
                          onPressed: () => _emailController.clear(),
                          splashRadius: 18,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Input Field
                  _ModernFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscurePassword,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _handleLogin(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return AuthService.validatePassword(value);
                    },
                    suffixWidget: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: const Color(0xFF9CA3AF),
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      splashRadius: 18,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Remember Me & Forgot Password Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Remember Me Checkbox
                      InkWell(
                        onTap: () => setState(() => _rememberMe = !_rememberMe),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _rememberMe ? trueBlack : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _rememberMe ? trueBlack : const Color(0xFFD1D5DB),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: _rememberMe
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: neonLime,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Remember me',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Forgot Password Link
                      TextButton(
                        onPressed: _showForgotPasswordDialog,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: trueBlack,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Primary Neon Green "Sign In" Button
                  _PrimaryActionButton(
                    label: 'Sign In',
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _handleLogin,
                  ),
                  const SizedBox(height: 28),

                  // "Or continue with" Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: inputBorder, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'Or continue with',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: inputBorder, height: 1)),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Full-width Google Sign-In Button
                  _GoogleAuthButton(
                    isLoading: _isGoogleLoading,
                    onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
                  ),
                  const SizedBox(height: 12),

                  // Full-width Facebook Sign-In Button
                  _FacebookAuthButton(
                    isLoading: _isFacebookLoading,
                    onPressed: (_isLoading || _isFacebookLoading) ? null : _handleFacebookSignIn,
                  ),
                  const SizedBox(height: 36),

                  // "Don't have an account? Sign up" footer
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: "Don't have an account? ",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: textMuted,
                          ),
                          children: [
                            TextSpan(
                              text: 'Sign up',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: trueBlack,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODERN FORM FIELD WITH FOCUS GLOW & INLINE VALIDATION
// ═══════════════════════════════════════════════════════════════════

class _ModernFormField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final Widget? suffixWidget;

  const _ModernFormField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.suffixWidget,
  });

  @override
  Widget build(BuildContext context) {
    const trueBlack = Color(0xFF121212);
    const inputBorder = Color(0xFFE5E7EB);
    const neonLime = Color(0xFFCEEB45);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: trueBlack,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: inputBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: inputBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: trueBlack, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppStyle.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppStyle.danger, width: 1.6),
        ),
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF9CA3AF),
        ),
        errorStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppStyle.danger,
        ),
        prefixIcon: Icon(
          icon,
          size: 20,
          color: const Color(0xFF9CA3AF),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        suffixIcon: suffixWidget,
        suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRIMARY ACTION BUTTON (NEON LIME WITH SHADOW)
// ═══════════════════════════════════════════════════════════════════

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const neonLime = Color(0xFFCEEB45);
    const trueBlack = Color(0xFF121212);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            color: neonLime,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: neonLime.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(trueBlack),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        color: trueBlack,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: trueBlack,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FULL-WIDTH GOOGLE AUTH BUTTON
// ═══════════════════════════════════════════════════════════════════

class _GoogleAuthButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleAuthButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const trueBlack = Color(0xFF121212);
    const inputBorder = Color(0xFFE5E7EB);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: inputBorder, width: 1.2),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 54,
          width: double.infinity,
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(trueBlack),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/google_logo.png',
                      height: 22,
                      width: 22,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.g_mobiledata_rounded,
                        size: 26,
                        color: trueBlack,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FacebookAuthButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _FacebookAuthButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const trueBlack = Color(0xFF121212);
    const inputBorder = Color(0xFFE5E7EB);
    const fbBlue = Color(0xFF1877F2);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: inputBorder, width: 1.2),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 54,
          width: double.infinity,
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(trueBlack),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.facebook_rounded,
                      size: 24,
                      color: fbBlue,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Facebook',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
