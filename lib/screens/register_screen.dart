import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_style.dart';
import '../services/auth_service.dart';
import '../widgets/google_auth_setup_dialog.dart';
import 'admin_dashboard.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _agreedToTerms = false;
  bool _showTermsError = false;

  static const Color neonLime = Color(0xFFC6FF33);
  static const Color trueBlack = Color(0xFF000000);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color inputBorder = Color(0xFFE5E7EB);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_agreedToTerms) {
      setState(() => _showTermsError = true);
    } else {
      setState(() => _showTermsError = false);
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreedToTerms) {
      _showToast(
        'Please accept the Terms of Service and Privacy Policy to continue.',
        isError: true,
      );
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() => _isLoading = true);
    final result = await AuthService.register(
      name: name,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _showToast(
        'Account created successfully! Please sign in.',
        isError: false,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      _showToast(
        result.error ?? 'Registration failed. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final result = await AuthService.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => result.role == 'admin'
              ? const AdminDashboard()
              : const HomeScreen(),
        ),
      );
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

  void _showTermsModal(BuildContext context, {required bool isPrivacy}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(
                    isPrivacy ? Icons.privacy_tip_outlined : Icons.description_outlined,
                    color: trueBlack,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isPrivacy ? 'Privacy Policy' : 'Terms of Service',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: trueBlack,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isPrivacy
                    ? 'At ScholarPath, we take your privacy and student data security seriously. Your account details, scholarship bookmarks, and application progress are encrypted and strictly confidential.\n\n• Information Collected: Name, email address, academic level, and preferences you provide.\n• Usage: Personalizing scholarship recommendations and keeping track of your application deadlines.\n• Data Protection: We never sell or share your personal information with unauthorized third parties.\n• Control: You can update or delete your profile information anytime from Settings.'
                    : 'Welcome to ScholarPath. By creating an account, you agree to adhere to our community terms:\n\n• Academic Integrity: Scholarship details and submission materials must be accurate and authentic.\n• Respectful Community: Engage responsibly with counselors, forums, and peers.\n• Service Availability: We continuously curate and verify global scholarship data to ensure accuracy.\n• Termination: Any fraudulent or abusive usage may result in account termination.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF374151),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _agreedToTerms = true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: trueBlack,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'I Understand & Agree',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: inputBorder, width: 1.2),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: trueBlack,
                        ),
                      ),
                    ),

                    // ScholarPath brand badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: inputBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/logo_combined.png',
                            height: 18,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.school_rounded,
                              size: 18,
                              color: trueBlack,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ScholarPath',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: trueBlack,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Title (Clean & appropriate for registration)
                Text(
                  'Create Account',
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
                  'Join ScholarPath to discover verified scholarships and track your applications.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),

                // Name input
                _ModernFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  hint: 'Full Name',
                  icon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name is too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Email input
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
                ),
                const SizedBox(height: 14),

                // Password input
                _ModernFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  hint: 'Create Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePassword,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
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
                const SizedBox(height: 14),

                // Confirm Password input
                _ModernFormField(
                  controller: _confirmPasswordController,
                  focusNode: _confirmFocusNode,
                  hint: 'Confirm Password',
                  icon: Icons.shield_outlined,
                  obscure: _obscureConfirm,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _register(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please re-type your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  suffixWidget: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: const Color(0xFF9CA3AF),
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    splashRadius: 18,
                  ),
                ),
                const SizedBox(height: 16),

                // Dynamic Password Strength & Rules Checklist
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _passwordController,
                  builder: (context, pass, _) {
                    return ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _confirmPasswordController,
                      builder: (context, confirm, _) => _PasswordStrengthCard(
                        password: pass.text,
                        confirm: confirm.text,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),

                // Terms & Privacy Checkbox
                InkWell(
                  onTap: () => setState(() {
                    _agreedToTerms = !_agreedToTerms;
                    if (_agreedToTerms) _showTermsError = false;
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: _agreedToTerms ? trueBlack : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _showTermsError
                                  ? AppStyle.danger
                                  : (_agreedToTerms ? trueBlack : const Color(0xFFD1D5DB)),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: _agreedToTerms
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: neonLime,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'I agree to the ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: _showTermsError ? AppStyle.danger : const Color(0xFF4B5563),
                                height: 1.45,
                              ),
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: () => _showTermsModal(context, isPrivacy: false),
                                    child: Text(
                                      'Terms of Service',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: trueBlack,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: () => _showTermsModal(context, isPrivacy: true),
                                    child: Text(
                                      'Privacy Policy',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: trueBlack,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Primary Neon Green "Sign Up" Button
                _PrimaryActionButton(
                  label: 'Create Account',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _register,
                ),
                const SizedBox(height: 26),

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
                const SizedBox(height: 20),

                // Full-width Google Sign-In Button
                _GoogleAuthButton(
                  isLoading: _isGoogleLoading,
                  onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
                ),
                const SizedBox(height: 32),

                // "Already have an account? Sign in" footer
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text.rich(
                      TextSpan(
                        text: 'Already have an account? ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign in',
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
                const SizedBox(height: 16),
              ],
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

class _ModernFormField extends StatefulWidget {
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
  State<_ModernFormField> createState() => _ModernFormFieldState();
}

class _ModernFormFieldState extends State<_ModernFormField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    const trueBlack = Color(0xFF000000);
    const inputBorder = Color(0xFFE5E7EB);
    const neonLime = Color(0xFFC6FF33);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _isFocused ? Colors.white : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFocused ? trueBlack : inputBorder,
          width: _isFocused ? 1.6 : 1.2,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: neonLime.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: trueBlack,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          hintText: widget.hint,
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
            widget.icon,
            size: 20,
            color: _isFocused ? trueBlack : const Color(0xFF9CA3AF),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: widget.suffixWidget,
          suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PASSWORD STRENGTH & INTERACTIVE CHECKLIST CARD
// ═══════════════════════════════════════════════════════════════════

class _PasswordStrengthCard extends StatelessWidget {
  final String password;
  final String confirm;

  const _PasswordStrengthCard({
    required this.password,
    required this.confirm,
  });

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty && confirm.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasMinLength = password.length >= 6;
    final hasNumberOrSpecial = RegExp(r'[0-9!@#\$&*~]').hasMatch(password);
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final passwordsMatch = confirm.isNotEmpty && password == confirm;

    int score = 0;
    if (hasMinLength) score++;
    if (hasNumberOrSpecial) score++;
    if (hasUppercase || password.length >= 8) score++;

    String strengthLabel = 'Too weak';
    Color strengthColor = AppStyle.danger;
    double progress = 0.25;

    if (score == 1) {
      strengthLabel = 'Weak';
      strengthColor = AppStyle.danger;
      progress = 0.35;
    } else if (score == 2) {
      strengthLabel = 'Fair';
      strengthColor = const Color(0xFFF59E0B);
      progress = 0.70;
    } else if (score >= 3) {
      strengthLabel = 'Strong';
      strengthColor = const Color(0xFF10B981);
      progress = 1.0;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Strength Bar & Label
          if (password.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Password Strength',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                Text(
                  strengthLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: strengthColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Requirements checklist
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _CheckItem(
                ok: hasMinLength,
                label: 'At least 6 characters',
              ),
              _CheckItem(
                ok: hasNumberOrSpecial,
                label: 'Contains number or symbol',
              ),
              if (confirm.isNotEmpty)
                _CheckItem(
                  ok: passwordsMatch,
                  label: passwordsMatch ? 'Passwords match' : 'Passwords don\'t match',
                  isStrict: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final bool ok;
  final String label;
  final bool isStrict;

  const _CheckItem({
    required this.ok,
    required this.label,
    this.isStrict = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color c = ok
        ? const Color(0xFF10B981)
        : (isStrict ? AppStyle.danger : const Color(0xFF9CA3AF));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : (isStrict ? Icons.cancel_rounded : Icons.circle_outlined),
          size: 13,
          color: c,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c,
          ),
        ),
      ],
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
    const neonLime = Color(0xFFC6FF33);
    const trueBlack = Color(0xFF000000);

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
    const trueBlack = Color(0xFF000000);
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
