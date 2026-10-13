import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_style.dart';
import '../services/app_translations.dart';
import '../providers/scholarship_provider.dart';
import 'ai_chat_screen.dart';

const String _supportEmail = 'support@brightly.com';
const String _supportDocsUrl = 'https://flutter.dev/docs';
const String _supportWhatsapp =
    'https://wa.me/6281297446236?text=Halo%20Brightly%2C%20saya%20butuh%20bantuan.';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: Column(
        children: [
          AppHeaders.pageHeader(
            context: context,
            title: 'Bantuan',
            subtitle: AppTranslations.get('help_subtitle'),
            leading: AppStyle.circleButton(
              context: context,
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
              size: 42,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                _HelpCard(
                  icon: Icons.auto_awesome_rounded,
                  title: AppTranslations.get('ai_assistant'),
                  subtitle: AppTranslations.get('ai_assistant_desc'),
                  color: AppStyle.accentOrange,
                  onTap: () {
                    final provider = context.read<ScholarshipProvider>();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AIChatScreen(
                          scholarships: provider.scholarships,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _HelpCard(
                  icon: Icons.chat_rounded,
                  title: 'Live Chat WhatsApp',
                  subtitle: 'Balasan cepat dari tim kami',
                  color: AppStyle.successGreen,
                  onTap: () => _open(context, _supportWhatsapp),
                ),
                const SizedBox(height: 12),
                _HelpCard(
                  icon: Icons.mail_rounded,
                  title: AppTranslations.get('email_support'),
                  subtitle: _supportEmail,
                  color: const Color(0xFFEA4335),
                  onTap: () => _open(
                    context,
                    'mailto:$_supportEmail?subject=${Uri.encodeQueryComponent('Bantuan Brightly')}',
                  ),
                ),
                const SizedBox(height: 12),
                _HelpCard(
                  icon: Icons.menu_book_rounded,
                  title: AppTranslations.get('documentation'),
                  subtitle: AppTranslations.get('documentation_desc'),
                  color: AppStyle.primaryBlue,
                  onTap: () => _open(context, _supportDocsUrl),
                ),
                const SizedBox(height: 28),
                _SubHeader(title: AppTranslations.get('faq')),
                const SizedBox(height: 12),
                _FaqItem(
                  question: AppTranslations.get('faq_1'),
                  answer: AppTranslations.get('faq_answer'),
                ),
                _FaqItem(
                  question: AppTranslations.get('faq_2'),
                  answer:
                      'Data kamu disimpan di Firebase dengan aturan keamanan '
                      'ketat. Hanya kamu dan admin yang bisa mengaksesnya.',
                ),
                _FaqItem(
                  question: AppTranslations.get('faq_3'),
                  answer:
                      'Bisa. Klik ikon bookmark pada kartu beasiswa untuk '
                      'menyimpannya, dan semua tersimpan di tab Tersimpan.',
                ),
                _FaqItem(
                  question: AppTranslations.get('faq_4'),
                  answer:
                      'Jawab 2 pertanyaan (region dan level), lalu kami akan '
                      'menampilkan rekomendasi beasiswa yang paling cocok.',
                ),
                const SizedBox(height: 30),
                Center(
                  child: Text(
                    'Brightly v1.0.2',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppStyle.getSubtitleColor(context),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tidak bisa membuka tautan'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HelpCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppStyle.getCardColor(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppStyle.getBorderColor(context), width: 1.2),
            boxShadow: AppStyle.softShadow(context),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppStyle.getTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppStyle.getSubtitleColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppStyle.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppStyle.getBorderColor(context), width: 1.2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            question,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppStyle.getTextColor(context),
            ),
          ),
          trailing: Icon(
            Icons.add_rounded,
            size: 20,
            color: AppStyle.getSubtitleColor(context),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  height: 1.6,
                  color: AppStyle.getSubtitleColor(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String title;

  const _SubHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 15,
          decoration: BoxDecoration(
            color: AppStyle.accentOrange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        // Flexible: a long FAQ heading used to overflow the row.
        Expanded(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyle.font(context, size: 12, weight: FontWeight.w800, spacing: 1.1),
          ),
        ),
      ],
    );
  }
}
