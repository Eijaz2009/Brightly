import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/scholarship_provider.dart';
import '../services/app_style.dart';
import '../services/app_translations.dart';
import '../services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'notifications_screen.dart';
import 'onboarding_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppTranslations.get('logout')),
        content: const Text('Kamu yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppStyle.danger),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.safeCurrentUser();
    final provider = context.watch<ScholarshipProvider>();
    final counts = provider.levelCounts;

    final name = AuthService.displayName(user);
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: AppStyle.background(
        context: context,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: AppStyle.topInset(context),
            bottom: AppStyle.bottomInset(context) + 96,
          ),
          child: Column(
            children: [
              // ── Profile hero ──
              AppStyle.avatar(context: context, name: name, size: 88),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                style: AppStyle.font(context, size: 21, weight: FontWeight.w800),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: AppStyle.font(
                    context,
                    size: 13,
                    weight: FontWeight.w500,
                    color: AppStyle.getSubtitleColor(context),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _PillButton(
                label: 'Edit profil',
                icon: Icons.edit_rounded,
                color: AppStyle.spark,
                onTap: () async {
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(currentName: name),
                    ),
                  );
                  if (changed != true || !context.mounted) return;
                  await provider.loadSession();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profil berhasil diperbarui')),
                  );
                },
              ),

              const SizedBox(height: 26),

              // ── Stats ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: AppStyle.statBubble(
                        context: context,
                        icon: Icons.bookmark_rounded,
                        value: '${provider.savedScholarships.length}',
                        label: 'Tersimpan',
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppStyle.statBubble(
                        context: context,
                        icon: Icons.school_rounded,
                        value: '${counts['S1'] ?? 0}',
                        label: 'Program S1',
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppStyle.statBubble(
                        context: context,
                        icon: Icons.public_rounded,
                        value: '${provider.scholarships.length}',
                        label: 'Total',
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _MenuGroup(
                title: 'AKUN',
                items: [
                  _MenuItem(
                    icon: Icons.psychology_alt_rounded,
                    title: 'Kuis beasiswa',
                    accent: AppStyle.spark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScholarshipQuizScreen(
                          scholarships: provider.scholarships,
                          onToggleBookmark: provider.toggleBookmark,
                        ),
                      ),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.notifications_rounded,
                    title: AppTranslations.get('notifications'),
                    accent: AppStyle.spark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _MenuGroup(
                title: 'PREFERENSI',
                items: [
                  _MenuItem(
                    icon: Icons.tune_rounded,
                    title: AppTranslations.get('settings'),
                    accent: AppStyle.spark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.help_outline_rounded,
                    title: AppTranslations.get('help_support'),
                    accent: AppStyle.spark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _logout(context),
                    borderRadius: BorderRadius.circular(AppStyle.rPill),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: AppStyle.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppStyle.rPill),
                        border: Border.all(
                          color: AppStyle.danger.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: AppStyle.danger,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppTranslations.get('logout'),
                            style: GoogleFonts.plusJakartaSans(
                              color: AppStyle.danger,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════════

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color.computeLuminance() > 0.55 ? AppStyle.ink : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppStyle.rPill),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppStyle.rPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _MenuGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(title, style: AppStyle.overline(context)),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppStyle.getCardColor(context),
              borderRadius: BorderRadius.circular(AppStyle.rLg),
              border: Border.all(color: AppStyle.getBorderColor(context)),
              boxShadow: AppStyle.softShadow(context),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i != items.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 64, right: 16),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: AppStyle.getBorderColor(context),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = accent.computeLuminance() > 0.55 ? AppStyle.ink : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppStyle.rLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(AppStyle.rSm),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: fg, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyle.font(context, size: 14, weight: FontWeight.w700),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppStyle.getSubtitleColor(context),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
