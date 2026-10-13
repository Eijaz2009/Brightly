import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_style.dart';
import '../services/app_translations.dart';

/// Normalises a notification document so `data['key']` is always safe.
Map<String, dynamic> dataOf(QueryDocumentSnapshot<Object?> doc) {
  final data = doc.data();
  if (data is Map<String, dynamic>) return data;
  return const <String, dynamic>{};
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final now = DateTime.now();
    final dt = ts.toDate();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _markAsRead(String docId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(docId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Mark notification read error: $e');
    }
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot<Object?>> docs) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || docs.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      // Batches cap at 500 writes.
      const chunk = 400;
      for (var i = 0; i < docs.length; i += chunk) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc
            in docs.sublist(i, (i + chunk).clamp(0, docs.length))) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Semua notifikasi ditandai sudah dibaca.'),
        ),
      );
    } catch (e) {
      debugPrint('Mark all read error: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal menandai notifikasi.'),
          backgroundColor: AppStyle.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: Column(
        children: [
          AppHeaders.pageHeader(
            context: context,
            title: 'Notifikasi',
            subtitle: AppTranslations.get('notif_subtitle'),
            leading: AppStyle.circleButton(
              context: context,
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
              size: 42,
            ),
          ),
          Expanded(
            child: uid == null
                ? _buildEmptyState(context)
                : StreamBuilder<QuerySnapshot<Object?>>(
                    // Bug fix: `orderBy('createdAt')` silently dropped any
                    // notification written without that field. Sorting happens
                    // in memory so nothing disappears.
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('notifications')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = <QueryDocumentSnapshot<Object?>>[
                        ...?snapshot.data?.docs,
                      ]..sort((a, b) {
                        final at = dataOf(a)['createdAt'] as Timestamp?;
                        final bt = dataOf(b)['createdAt'] as Timestamp?;
                        if (at == null && bt == null) return 0;
                        if (at == null) return 1;
                        if (bt == null) return -1;
                        return bt.compareTo(at);
                      });

                      if (docs.isEmpty) {
                        return _buildEmptyState(context);
                      }

                      final unread = docs
                          .where((d) => dataOf(d)['read'] != true)
                          .toList(growable: false);

                      return Column(
                        children: [
                          if (unread.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${unread.length} belum dibaca',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppStyle.getSubtitleColor(
                                          context,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _markAllAsRead(unread),
                                    icon: const Icon(
                                      Icons.done_all_rounded,
                                      size: 16,
                                      color: AppStyle.primaryBlue,
                                    ),
                                    label: Text(
                                      'Tandai dibaca',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppStyle.primaryBlue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = dataOf(doc);
                                final isRead = data['read'] == true;
                                final ts = data['createdAt'] as Timestamp?;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _NotificationTile(
                                    data: data,
                                    isRead: isRead,
                                    time: _formatTime(ts),
                                    onTap: () => _markAsRead(doc.id),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppStyle.primaryBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 42,
                color: AppStyle.primaryBlue.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Belum ada notifikasi',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppStyle.getTextColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kami akan mengabari kamu saat ada beasiswa baru atau tenggat '
              'yang mendekati.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppStyle.getSubtitleColor(context),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isRead;
  final String time;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.data,
    required this.isRead,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString();
    final desc = data['desc']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead
                ? AppStyle.getCardColor(context)
                : AppStyle.primaryBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRead
                  ? AppStyle.getBorderColor(context)
                  : AppStyle.primaryBlue.withValues(alpha: 0.2),
              width: isRead ? 1 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppStyle.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  data['icon']?.toString() ?? '🔔',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            (title == null || title.isEmpty)
                                ? 'Notifikasi'
                                : title,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight:
                                  isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 14,
                              height: 1.3,
                              color: AppStyle.getTextColor(context),
                            ),
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: AppStyle.accentOrange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        desc,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppStyle.getSubtitleColor(context),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        time,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppStyle.getSubtitleColor(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
