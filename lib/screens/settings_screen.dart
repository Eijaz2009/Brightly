import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_style.dart';
import '../services/app_state.dart';
import '../services/app_translations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppStyle.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppTranslations.get('select_language'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyle.getTextColor(context),
                ),
              ),
              const SizedBox(height: 24),
              _buildLanguageOption('English (US)', 'en', '🇺🇸'),
              const SizedBox(height: 12),
              _buildLanguageOption('Bahasa Indonesia', 'id', '🇮🇩'),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String name, String code, String flag) {
    final bool isSelected = AppState.localeNotifier.value.languageCode == code;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        AppState.setLocale(code);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppTranslations.get('language_changed')} $name'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppStyle.primaryBlue,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppStyle.primaryBlue.withValues(alpha: 0.1) 
              : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF0F0F0)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppStyle.primaryBlue : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFD5D5D5)),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 16),
            Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppStyle.primaryBlue : AppStyle.getTextColor(context),
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppStyle.primaryBlue),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: Column(
        children: [
          AppHeaders.pageHeader(
            context: context,
            title: 'Pengaturan',
            subtitle: AppTranslations.get('settings_subtitle'),
            leading: AppStyle.circleButton(
              context: context,
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
              size: 42,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(AppTranslations.get('general_settings')),
                  
                  // Push Notifications
                  ValueListenableBuilder<bool>(
                    valueListenable: AppState.pushNotificationsEnabled,
                    builder: (context, enabled, _) {
                      return _buildSettingItem(
                        icon: Icons.notifications_active_rounded,
                        title: AppTranslations.get('push_notifications'),
                        subtitle: AppTranslations.get('push_notifications_desc'),
                        trailing: Switch(
                          value: enabled,
                          onChanged: (val) {
                            AppState.setNotifications(val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(val ? AppTranslations.get('notifications_enabled') : AppTranslations.get('notifications_disabled')),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          activeThumbColor: AppStyle.getPrimaryBlue(context),
                        ),
                      );
                    },
                  ),

                  // Dark Mode
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: AppState.themeNotifier,
                    builder: (context, mode, _) {
                      final bool isDarkNow = mode == ThemeMode.dark;
                      return _buildSettingItem(
                        icon: Icons.dark_mode_rounded,
                        title: AppTranslations.get('dark_mode'),
                        subtitle: AppTranslations.get('dark_mode_desc'),
                        trailing: Switch(
                          value: isDarkNow,
                          onChanged: (val) => AppState.toggleTheme(val),
                          activeThumbColor: AppStyle.getPrimaryBlue(context),
                        ),
                      );
                    },
                  ),

                  // Language
                  ValueListenableBuilder<Locale>(
                    valueListenable: AppState.localeNotifier,
                    builder: (context, locale, _) {
                      final String langName = locale.languageCode == 'en' ? 'English (US)' : 'Bahasa Indonesia';
                      return GestureDetector(
                        onTap: _showLanguagePicker,
                        child: _buildSettingItem(
                          icon: Icons.language_rounded,
                          title: AppTranslations.get('app_language'),
                          subtitle: langName,
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle(AppTranslations.get('other')),
                  GestureDetector(
                    onTap: () async {
                      // Real cache clear: images + pending image requests.
                      PaintingBinding.instance.imageCache
                        ..clear()
                        ..clearLiveImages();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppTranslations.get('cache_cleared')),
                          backgroundColor: AppStyle.getPrimaryBlue(context),
                        ),
                      );
                    },
                    child: _buildSettingItem(
                      icon: Icons.cached_rounded,
                      title: AppTranslations.get('clear_cache'),
                      subtitle: AppTranslations.get('clear_cache_desc'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showRateDialog(),
                    child: _buildSettingItem(
                      icon: Icons.star_rounded,
                      title: AppTranslations.get('rate_app'),
                      subtitle: AppTranslations.get('rate_app_desc'),
                      color: Colors.amber,
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle(AppTranslations.get('about')),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppStyle.getCardColor(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text(AppTranslations.get('terms_privacy'), style: TextStyle(color: AppStyle.getTextColor(context), fontWeight: FontWeight.bold)),
                          content: Text(
                            AppTranslations.get('terms_privacy_content'),
                            style: TextStyle(color: AppStyle.getSubtitleColor(context), fontSize: 13, height: 1.5),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(AppTranslations.get('close'), style: TextStyle(color: AppStyle.getPrimaryBlue(context))),
                            ),
                          ],
                        ),
                      );
                    },
                    child: _buildSettingItem(
                      icon: Icons.description_rounded,
                      title: AppTranslations.get('terms_privacy'),
                      subtitle: AppTranslations.get('terms_privacy_desc'),
                      color: Colors.teal,
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showAboutDialog(),
                    child: _buildSettingItem(
                      icon: Icons.info_rounded,
                      title: AppTranslations.get('about_app'),
                      subtitle: 'Brightly v1.0.2',
                      color: Colors.deepPurple,
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _selectedRating = 0;

  void _showRateDialog() {
    _selectedRating = 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final labels = ['', 'Terrible', 'Bad', 'Okay', 'Good', 'Amazing!'];
            final label = _selectedRating > 0 ? labels[_selectedRating] : '';

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              decoration: BoxDecoration(
                color: AppStyle.getCardColor(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppStyle.getSubtitleColor(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // App icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppStyle.getGradient(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('🎓', style: TextStyle(fontSize: 32)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Enjoying Brightly?',
                    style: TextStyle(
                      color: AppStyle.getTextColor(context),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your feedback helps us improve the experience\nfor students everywhere.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppStyle.getSubtitleColor(context),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final isSelected = i < _selectedRating;
                      return GestureDetector(
                        onTap: () => setSheetState(() => _selectedRating = i + 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.amber.withValues(alpha: 0.15)
                                : AppStyle.getSubtitleColor(context).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.amber.withValues(alpha: 0.4)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: AnimatedScale(
                              scale: isSelected ? 1.1 : 0.9,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: isSelected ? Colors.amber : AppStyle.getSubtitleColor(context),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Label
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: TextStyle(
                        color: _selectedRating >= 4
                            ? Colors.amber[700]
                            : AppStyle.getSubtitleColor(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _selectedRating > 0
                          ? () async {
                              final messenger =
                                  ScaffoldMessenger.of(this.context);
                              final navigator = Navigator.of(ctx);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Menyimpan penilaianmu...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );

                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) {
                                // Firestore rules require an authenticated
                                // user to submit a review.
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Masuk dulu untuk mengirim penilaian.',
                                    ),
                                    backgroundColor: AppStyle.errorRed,
                                  ),
                                );
                                return;
                              }

                              try {
                                await FirebaseFirestore.instance
                                    .collection('ratings')
                                    .add(<String, dynamic>{
                                      'rating': _selectedRating,
                                      'userId': user.uid,
                                      'userName':
                                          user.displayName ?? user.email ?? 'User',
                                      'userEmail': user.email ?? '',
                                      'createdAt':
                                          FieldValue.serverTimestamp(),
                                    });

                                if (!mounted) return;
                                navigator.pop();
                                ScaffoldMessenger.of(this.context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppTranslations.get('rate_thanks'),
                                    ),
                                    backgroundColor: AppStyle.successGreen,
                                  ),
                                );
                              } catch (e) {
                                debugPrint('Rating submit error: $e');
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal menyimpan rating: $e'),
                                    backgroundColor: AppStyle.errorRed,
                                  ),
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyle.getPrimaryBlue(context),
                        disabledBackgroundColor: AppStyle.getSubtitleColor(context).withValues(alpha: 0.15),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: AppStyle.getSubtitleColor(context),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: _selectedRating > 0 ? 4 : 0,
                        shadowColor: AppStyle.getPrimaryBlue(context).withValues(alpha: 0.3),
                      ),
                      child: const Text('Submit Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Text(
                      'Maybe Later',
                      style: TextStyle(
                        color: AppStyle.getSubtitleColor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppStyle.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppStyle.getGradient(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text('🎓', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Brightly',
              style: TextStyle(
                color: AppStyle.getTextColor(context),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'v1.0.2',
              style: TextStyle(color: AppStyle.getSubtitleColor(context), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Divider(color: AppStyle.getSubtitleColor(context).withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            _aboutInfoRow(Icons.code_rounded, 'Flutter & Firebase'),
            _aboutInfoRow(Icons.person_rounded, 'Developer: Brightly Team'),
            _aboutInfoRow(Icons.email_rounded, 'support@brightly.com'),
            _aboutInfoRow(Icons.copyright_rounded, '© 2025 Brightly'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppTranslations.get('close'), style: TextStyle(color: AppStyle.getPrimaryBlue(context))),
          ),
        ],
      ),
    );
  }

  Widget _aboutInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppStyle.getPrimaryBlue(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppStyle.getSubtitleColor(context), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: AppStyle.getTextColor(context),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color color = AppStyle.primaryBlue,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppStyle.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppStyle.cardShadow(context),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppStyle.getTextColor(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppStyle.getSubtitleColor(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
