import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_style.dart';
import '../services/auth_service.dart';
import 'admin_dashboard.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Keep the splash visible long enough for the logo to breathe.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    try {
      // Finish a Google redirect sign-in first. When the browser popup is
      // blocked we fall back to a full-page redirect, which restarts the app
      // with the credential in the URL; without this the user would bounce
      // straight back to the login screen despite being signed in.
      final redirectResult = await AuthService.completeRedirectSignIn();
      if (!mounted) return;

      if (redirectResult != null && !redirectResult.success) {
        if (redirectResult.isBlocked) {
          await AuthService.signOut();
        } else {
          _toast(
            redirectResult.error ?? 'Login Google gagal.',
            AppStyle.danger,
          );
        }
        if (!mounted) return;
        _go(const LoginScreen());
        return;
      }

      final user = AuthService.currentUser;

      // 1. Maintenance gate (readable pre-auth).
      final config = await AuthService.getSystemConfig();
      if (config['maintenanceMode'] == true) {
        final isAdmin = user != null && await AuthService.isCurrentUserAdmin();
        if (!isAdmin && mounted) {
          _go(const MaintenanceScreen());
          return;
        }
      }

      if (!mounted) return;

      if (user == null) {
        _go(const OnboardingScreen());
        return;
      }

      // 2. Blocked account?
      if (await AuthService.isCurrentUserBlocked()) {
        await AuthService.signOut();
        if (!mounted) return;
        _go(const LoginScreen());
        _toast(
          'Akun kamu telah dinonaktifkan. Hubungi administrator.',
          AppStyle.danger,
        );
        return;
      }

      // 3. Role routing.
      final isAdmin = await AuthService.isCurrentUserAdmin();
      if (!mounted) return;
      _go(isAdmin ? const AdminDashboard() : const HomeScreen());
    } catch (e) {
      debugPrint('Splash initialization error: $e');
      if (mounted) _go(const LoginScreen());
    }
  }

  void _go(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    const trueBlack = Color(0xFF121212);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/brightly_custom_logo.png',
                width: 110,
                height: 110,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              Text(
                'Brightly',
                style: GoogleFonts.plusJakartaSans(
                  color: trueBlack,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Scholarship & Education Platform',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: trueBlack.withValues(alpha: 0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the admin has flipped `config/system.maintenanceMode`.
///
/// Own route with its own retry logic — the previous version called the splash
/// State's already-disposed context, so "Try Again" did nothing.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    final config = await AuthService.getSystemConfig();
    final stillMaintenance = config['maintenanceMode'] == true;

    if (!mounted) return;
    setState(() => _checking = false);

    if (stillMaintenance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App masih dalam mode maintenance.')),
      );
      return;
    }

    final user = AuthService.currentUser;
    if (user == null) {
      _go(const LoginScreen());
      return;
    }

    final isAdmin = await AuthService.isCurrentUserAdmin();
    if (!mounted) return;
    _go(isAdmin ? const AdminDashboard() : const HomeScreen());
  }

  void _go(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: AppStyle.background(
        context: context,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: AppStyle.sunny.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Icon(
                      Icons.construction_rounded,
                      size: 56,
                      color: AppStyle.sunny,
                    ),
                    Positioned(
                      top: 8,
                      right: 14,
                      child: AppStyle.sparkles(size: 13, count: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Segera Hadir',
                  style: AppStyle.font(context, size: 26, weight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'Brightly sedang dalam pemeliharaan rutin agar pengalamannya '
                  'lebih baik. Kami akan segera kembali!',
                  textAlign: TextAlign.center,
                  style: AppStyle.font(
                    context,
                    size: 14,
                    weight: FontWeight.w500,
                    color: AppStyle.getSubtitleColor(context),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                AppStyle.primaryButton(
                  context: context,
                  label: 'Coba lagi',
                  icon: Icons.refresh_rounded,
                  loading: _checking,
                  onPressed: _checking ? () {} : _retry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
