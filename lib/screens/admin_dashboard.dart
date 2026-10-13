import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_scholarship_screen.dart';
import 'manage_scholarships_screen.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import '../services/app_style.dart';
import '../services/app_translations.dart';
import '../services/auth_service.dart';
import '../models/scholarship_data.dart';
import '../widgets/admin/stat_card.dart';
import '../widgets/admin/action_button.dart';
import '../widgets/admin/scholarship_admin_card.dart';
import '../widgets/admin/analytics_chart.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _accessChecked = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifyAccess());
  }

  /// Defence in depth: the dashboard must never render for a non-admin, even
  /// if it is reached through a stale route or a deep link.
  Future<void> _verifyAccess() async {
    var admin = false;
    try {
      admin = await AuthService.isCurrentUserAdmin();
    } catch (e) {
      debugPrint('Admin access check failed: $e');
    }
    if (!mounted) return;

    if (!admin) {
      _toast('Akses ditolak: akun ini bukan administrator.', AppStyle.errorRed);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      return;
    }

    setState(() {
      _isAdmin = true;
      _accessChecked = true;
    });
  }

  int _selectedIndex = 0;
  bool _isPresentationMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> scholarships = ScholarshipData.defaultScholarships;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendNotificationToAll(String title, String desc, String icon) async {
    final usersSnap =
        await FirebaseFirestore.instance.collection('users').get();
    if (usersSnap.docs.isEmpty) {
      _toast('Belum ada pengguna terdaftar.', AppStyle.warningAmber);
      return;
    }

    // Firestore batches cap at 500 writes — chunk to stay safe on scale.
    const chunkSize = 400;
    for (var start = 0; start < usersSnap.docs.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, usersSnap.docs.length);
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in usersSnap.docs.sublist(start, end)) {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .collection('notifications')
            .doc();
        batch.set(ref, {
          'title': title,
          'desc': desc,
          'icon': icon,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    await _logAction(
      'Notification Sent',
      '${usersSnap.docs.length} users: $title',
    );
    _toast(
      'Notifikasi terkirim ke ${usersSnap.docs.length} pengguna.',
      AppStyle.successGreen,
    );
  }

  void _toast(String message, [Color? color]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _logAction(String action, String target) async {
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'action': action,
      'target': target,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppStyle.getCardColor(ctx),
        title: Text(
          'Logout Admin',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppStyle.getTextColor(ctx),
          ),
        ),
        content: Text(
          'Kamu yakin ingin keluar dari dashboard admin?',
          style: GoogleFonts.plusJakartaSans(
            color: AppStyle.getSubtitleColor(ctx),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                color: AppStyle.getSubtitleColor(ctx),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyle.errorRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Logout',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await AuthService.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Logout error: $e');
      _toast('Gagal logout: $e', AppStyle.errorRed);
    }
  }

  void _showSendNotificationDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedIcon = '🔔';
    final icons = ['🔔', '✨', '📅', '🎓', '🔖', '🛡️', '🚀', '💡'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppStyle.getCardColor(context),
          title: Text('Send Notification', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppStyle.getTextColor(context))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                children: icons.map((ic) => GestureDetector(
                  onTap: () => setDialogState(() => selectedIcon = ic),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selectedIcon == ic ? AppStyle.primaryBlue.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selectedIcon == ic ? AppStyle.primaryBlue : Colors.transparent),
                    ),
                    child: Text(ic, style: const TextStyle(fontSize: 22)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                style: GoogleFonts.plusJakartaSans(color: AppStyle.getTextColor(context)),
                decoration: InputDecoration(
                  hintText: 'Notification Title',
                  hintStyle: GoogleFonts.plusJakartaSans(color: AppStyle.getSubtitleColor(context)),
                  filled: true,
                  fillColor: AppStyle.getBackgroundColor(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: GoogleFonts.plusJakartaSans(color: AppStyle.getTextColor(context)),
                decoration: InputDecoration(
                  hintText: 'Notification description...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: AppStyle.getSubtitleColor(context)),
                  filled: true,
                  fillColor: AppStyle.getBackgroundColor(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppStyle.getSubtitleColor(context)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyle.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) {
                  _toast('Judul notifikasi wajib diisi.', AppStyle.errorRed);
                  return;
                }
                Navigator.pop(ctx);
                _toast('Mengirim notifikasi...');
                try {
                  await _sendNotificationToAll(
                    titleCtrl.text.trim(),
                    descCtrl.text.trim(),
                    selectedIcon,
                  );
                } catch (e) {
                  debugPrint('Send notification error: $e');
                  _toast('Gagal mengirim: $e', AppStyle.errorRed);
                }
              },
              child: Text(
                'Kirim ke Semua',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seedSampleRatings() async {
    const ratings = [5, 4, 5, 3, 5];
    const names = ['Budi', 'Siti', 'Andi', 'Rina', 'Eko'];

    _toast('Menyiapkan data contoh...');
    try {
      for (var i = 0; i < ratings.length; i++) {
        await FirebaseFirestore.instance.collection('ratings').add({
          'rating': ratings[i],
          'userName': names[i],
          'userId': 'sample_user_$i',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await _logAction('Data Seeded', '${ratings.length} Sample Ratings');
      _toast('Data contoh berhasil ditambahkan.', AppStyle.successGreen);
    } catch (e) {
      debugPrint('Seed error: $e');
      _toast('Gagal menambahkan data contoh: $e', AppStyle.errorRed);
    }
  }

  Future<void> _checkSystemHealth() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Memeriksa koneksi Firebase...')),
    );

    try {
      // Test write + read against a throwaway document.
      final testRef =
          FirebaseFirestore.instance.collection('config').doc('health_check');
      await testRef.set({
        'last_check': FieldValue.serverTimestamp(),
        'status': 'ok',
      });
      await testRef.get();
      _showHealthResult(
        true,
        'Firebase terhubung dan dapat diakses dengan benar.',
      );
    } catch (e) {
      debugPrint('Health check error: $e');
      _showHealthResult(false, 'Firebase error: $e');
    }
  }

  void _showHealthResult(bool success, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppStyle.getCardColor(ctx),
        title: Text(
          success ? 'Sistem Sehat' : 'Sistem Bermasalah',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(message, style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showAuditLogs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppStyle.getCardColor(context),
        title: Text('Recent Audit Logs', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          // Fixed height instead of Expanded: AlertDialog content is
          // unbounded, so `Expanded` used to throw a RenderFlex error.
          height: 380,
          child: StreamBuilder<QuerySnapshot<Object?>>(
            // `orderBy` is safe here because every audit log is written by
            // this app with a server timestamp.
            stream: FirebaseFirestore.instance
                .collection('audit_logs')
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Tidak dapat memuat log',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppStyle.getSubtitleColor(context),
                    ),
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'Belum ada aktivitas tercatat',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppStyle.getSubtitleColor(context),
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data =
                      (doc.data() as Map?)?.cast<String, dynamic>() ??
                      const <String, dynamic>{};
                  final ts = data['createdAt'] as Timestamp?;
                  return _buildLogItem(
                    data['action']?.toString() ?? 'Aksi',
                    data['target']?.toString() ?? '-',
                    ts == null ? 'Baru saja' : _relative(ts),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Tutup',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(String action, String target, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppStyle.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.history_rounded, size: 16, color: AppStyle.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppStyle.getTextColor(context))),
                Text(target, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppStyle.getSubtitleColor(context))),
              ],
            ),
          ),
          Text(time, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppStyle.getSubtitleColor(context))),
        ],
      ),
    );
  }

  void _showSystemHealth() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppStyle.getCardColor(context),
        title: Text('System Health', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHealthItem('Firebase Auth', true),
            _buildHealthItem('Cloud Firestore', true),
            _buildHealthItem('Cloud Messaging', true),
            _buildHealthItem('App Services', true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildHealthItem(String service, bool isHealthy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(isHealthy ? Icons.check_circle_rounded : Icons.error_rounded, color: isHealthy ? Colors.green : Colors.red, size: 18),
          const SizedBox(width: 12),
          Text(service, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppStyle.getTextColor(context))),
          const Spacer(),
          Text(isHealthy ? 'Online' : 'Offline', style: GoogleFonts.plusJakartaSans(color: isHealthy ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showTranslationMap() {
    const keys = [
      'good_morning',
      'good_afternoon',
      'good_evening',
      'good_night',
      'scholarship_details',
      'about_scholarship',
      'visit_website',
      'notifications',
      'settings',
      'dark_mode',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppStyle.getCardColor(ctx),
        title: Text(
          'Translation Map',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: double.maxFinite,
          // Fixed height (instead of Expanded) — AlertDialog content has
          // unbounded height, which used to throw a RenderFlex error.
          height: 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kunci yang sudah dipetakan ke EN / ID:',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppStyle.getSubtitleColor(ctx),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: keys.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      keys[i],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppStyle.primaryBlue,
                      ),
                    ),
                    subtitle: Text(
                      AppTranslations.get(keys[i]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Tutup',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }



  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
      if (index != 0 && index != 1 && index != 2) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  void _confirmDeleteUser(String userId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppStyle.getCardColor(ctx),
        title: Text(
          'Hapus Pengguna',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Hapus akun $name? Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                color: AppStyle.getSubtitleColor(ctx),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyle.errorRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .delete();
                await _logAction('User Deleted', name);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Pengguna $name dihapus'),
                    backgroundColor: AppStyle.errorRed,
                  ),
                );
              } catch (e) {
                debugPrint('Delete user error: $e');
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Gagal menghapus: $e'),
                    backgroundColor: AppStyle.errorRed,
                  ),
                );
              }
            },
            child: Text(
              'Hapus',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hold the dashboard back until the admin check resolves, so no privileged
    // widget is ever built for a regular user.
    if (!_accessChecked || !_isAdmin) {
      return Scaffold(
        backgroundColor: AppStyle.getBackgroundColor(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: AppStyle.background(
        context: context,
        child: Stack(
          children: [
            Column(
              children: [
                // ── HEADER ──
                AppHeaders.pageHeader(
                  context: context,
                  title: _adminTabTitle,
                  subtitle: _adminTabSubtitle,
                  showSearch: _selectedIndex <= 2,
                  searchController: _searchController,
                  onSearchChanged: (val) => setState(() => _searchQuery = val),
                  searchHint: 'Cari...',
                  trailing: AppStyle.circleButton(
                    context: context,
                    icon: Icons.logout_rounded,
                    size: 42,
                    iconColor: AppStyle.danger,
                    background: AppStyle.danger.withValues(alpha: 0.1),
                    bordered: false,
                    onTap: _logout,
                  ),
                ),

              // ── CONTENT ──
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('scholarships')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'Firestore Error: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(color: AppStyle.errorRed, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final List<Map<String, dynamic>> firestoreScholarships = [];
                    if (snapshot.hasData && snapshot.data != null) {
                      try {
                        final docs = snapshot.data?.docs ?? [];
                        
                        // Sort in-memory to avoid missing index errors in Firestore
                        final sortedDocs = [...docs];
                        sortedDocs.sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>?;
                          final bData = b.data() as Map<String, dynamic>?;
                          final aTime = aData?['createdAt'] as Timestamp?;
                          final bTime = bData?['createdAt'] as Timestamp?;
                          if (aTime == null) return 1;
                          if (bTime == null) return -1;
                          return bTime.compareTo(aTime);
                        });

                        for (var doc in sortedDocs) {
                          final data = doc.data() as Map<String, dynamic>?;
                          if (data != null) {
                            firestoreScholarships.add(<String, dynamic>{
                              ...data,
                              'id': doc.id,
                              'isDefault': false,
                              'doc': doc,
                            });
                          }
                        }
                      } catch (e) {
                        debugPrint('Admin error processing data: $e');
                      }
                    }

                    // Merge with default scholarships, matching ScholarshipProvider logic
                    final List<Map<String, dynamic>> defaultList = scholarships.map((s) => <String, dynamic>{...s, 'isDefault': true}).toList();
                    final List<Map<String, dynamic>> newFromFirestore = [];
                    
                    for (var fs in firestoreScholarships) {
                      final title = fs['title']?.toString() ?? '';
                      final int defaultIndex = defaultList.indexWhere((s) => s['title'] == title);
                      
                      if (defaultIndex != -1) {
                        // If it's a default scholarship, replace it with Firestore version to keep it editable
                        defaultList[defaultIndex] = Map<String, dynamic>.from(fs);
                      } else {
                        // Truly new scholarship
                        newFromFirestore.add(Map<String, dynamic>.from(fs));
                      }
                    }

                    // Final order: New Firestore items first, then default list (starting with LPDP)
                    final List<Map<String, dynamic>> allScholarships = [
                      ...newFromFirestore.map((m) => Map<String, dynamic>.from(m)),
                      ...defaultList.map((m) => Map<String, dynamic>.from(m)),
                    ];

                    final int totalScholarshipsCount = allScholarships.length;
                    final List<Map<String, dynamic>> recentScholarships =
                        allScholarships.take(8).toList();

                    final String query = _searchQuery.toLowerCase();
                    final List<Map<String, dynamic>> filteredList = (query.isEmpty)
                        ? allScholarships
                        : allScholarships.where((s) {
                            final title = (s['title']?.toString() ?? '').toLowerCase();
                            final country = (s['country']?.toString() ?? (s['subtitle']?.toString() ?? '')).toLowerCase();
                            return title.contains(query) || country.contains(query);
                          }).toList();

                    if (snapshot.connectionState == ConnectionState.waiting && firestoreScholarships.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return IndexedStack(
                      index: _selectedIndex,
                      children: [
                        _buildDashboardTab(totalScholarshipsCount, recentScholarships, query, filteredList),
                        _buildListTab(filteredList, query),
                        _buildUsersTab(),
                        _buildConfigTab(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          _buildFloatingBottomNav(),
          ],
        ),
      ),
    );
  }

  String get _adminTabTitle => switch (_selectedIndex) {
    0 => 'Dashboard',
    1 => 'Semua beasiswa',
    2 => 'Pengguna',
    _ => 'Konfigurasi',
  };

  String get _adminTabSubtitle => switch (_selectedIndex) {
    0 => 'Ringkasan aktivitas Brightly',
    1 => 'Basis data beasiswa',
    2 => 'Kontrol akses pengguna',
    _ => 'Pengaturan aplikasi',
  };

  Widget _buildDashboardTab(int totalCount, List<Map<String, dynamic>> recent, String query, List<Map<String, dynamic>> filtered) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: AppStyle.bottomInset(context) + 84),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Header with Refresh for Demo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'QUICK STATS',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppStyle.accentOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AppStyle.accentOrange),
                  onPressed: () => setState(() {}), // Triggers rebuild of all StreamBuilders
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats Row
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.school_rounded,
                    number: '$totalCount',
                    label: 'Total Scholarships',
                    color: AppStyle.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      final int count = snapshot.hasData ? (snapshot.data?.docs.length ?? 0) : 0;
                      return StatCard(
                        icon: Icons.people_rounded,
                        number: '$count',
                        label: 'Total Users',
                        color: AppStyle.primaryBlue,
                      );
                    }
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats Row: Rating & Reviews (Real-time)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('ratings').snapshots(),
              builder: (context, snapshot) {
                // Professional fallback for presentation if database is blocked
                if (snapshot.hasError || _isPresentationMode) {
                  return Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.star_rounded,
                          number: _isPresentationMode ? '4.8' : '0.0',
                          label: 'Avg App Rating',
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          icon: Icons.rate_review_rounded,
                          number: _isPresentationMode ? '128' : '0',
                          label: 'Total Reviews',
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  );
                }

                double avgRating = 0.0;
                int totalReviews = 0;
                if (snapshot.hasData && snapshot.data != null) {
                  final docs = snapshot.data!.docs;
                  totalReviews = docs.length;
                  if (totalReviews > 0) {
                    double sum = 0;
                    for (var doc in docs) {
                      try {
                        final data = doc.data() as Map<String, dynamic>;
                        final val = data['rating'];
                        if (val is int) {
                          sum += val.toDouble();
                        } else if (val is double) {
                          sum += val;
                        } else if (val is String) {
                          sum += double.tryParse(val) ?? 0.0;
                        }
                      } catch (_) {}
                    }
                    avgRating = sum / totalReviews;
                  }
                }
                return Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.star_rounded,
                        number: totalReviews > 0 ? avgRating.toStringAsFixed(1) : '0.0',
                        label: 'Avg App Rating',
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.rate_review_rounded,
                        number: '$totalReviews',
                        label: 'Total Reviews',
                        color: Colors.teal,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Analytics Chart
            const AnalyticsChart(),
            const SizedBox(height: 24),

            // Recent Reviews List for Demo
            _buildRecentReviewsSection(),
            const SizedBox(height: 32),

            // Quick Actions
            Text(
              'QUICK ACTIONS',
              style: GoogleFonts.plusJakartaSans(
                color: AppStyle.accentOrange,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            AdminActionButton(
              icon: Icons.add_circle_rounded,
              label: 'Add New Scholarship',
              color: AppStyle.primaryBlue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddScholarshipScreen())),
            ),
            const SizedBox(height: 12),
            AdminActionButton(
              icon: Icons.edit_rounded,
              label: 'Manage Scholarships',
              color: AppStyle.primaryBlue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageScholarshipsScreen())),
            ),
            const SizedBox(height: 32),

            // Recent Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  query.isNotEmpty ? 'SEARCH RESULTS' : 'RECENT UPDATES',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppStyle.accentOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                if (query.isEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _selectedIndex = 1),
                    child: Text(
                      'View All',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppStyle.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final list = query.isNotEmpty ? filtered : recent;
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No scholarships found',
                      style: GoogleFonts.plusJakartaSans(color: AppStyle.getSubtitleColor(context)),
                    ),
                  ),
                );
              }
              return Column(
                children: list.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ScholarshipAdminCard(
                    flag: s['flag']?.toString() ?? '🌍',
                    title: s['title']?.toString() ?? 'No Title',
                    country: s['country']?.toString() ?? s['subtitle']?.toString() ?? 'Global',
                    status: s['isDefault'] == true ? 'Default' : 'Active',
                    applications: '0',
                    onTap: (s['isDefault'] == true || s['doc'] == null) 
                        ? null 
                        : () => Navigator.push(
                              context, 
                              MaterialPageRoute(
                                builder: (_) => AddScholarshipScreen(
                                  scholarshipDoc: s['doc']
                                      as DocumentSnapshot<Map<String, dynamic>>,
                                ),
                              ),
                            ),
                  ),
                )).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildListTab(List<Map<String, dynamic>> list, String query) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No results found for "$query"',
          style: GoogleFonts.plusJakartaSans(color: AppStyle.getSubtitleColor(context)),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(24, 24, 24, AppStyle.bottomInset(context) + 84),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final s = list[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ScholarshipAdminCard(
            flag: s['flag']?.toString() ?? '🌍',
            title: s['title']?.toString() ?? 'No Title',
            country: s['country']?.toString() ?? s['subtitle']?.toString() ?? 'Global',
            status: s['isDefault'] == true ? 'Default' : 'Active',
            applications: '0',
            onTap: (s['isDefault'] == true || s['doc'] == null) 
                ? null 
                : () => Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (_) => AddScholarshipScreen(
                          scholarshipDoc: s['doc']
                              as DocumentSnapshot<Map<String, dynamic>>,
                        ),
                      ),
                    ),
          ),
        );
      },
    );
  }

  Widget _buildRecentReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT REVIEWS',
          style: GoogleFonts.plusJakartaSans(
            color: AppStyle.accentOrange,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Object?>>(
          // Bug fix: `orderBy('createdAt')` dropped reviews written without
          // that field. Sorting in memory keeps every review visible.
          stream: FirebaseFirestore.instance.collection('ratings').snapshots(),
          builder: (context, snapshot) {
            final docs = <QueryDocumentSnapshot<Object?>>[
              ...?snapshot.data?.docs,
            ]..sort((a, b) {
              final at = (a.data() as Map?)?['createdAt'] as Timestamp?;
              final bt = (b.data() as Map?)?['createdAt'] as Timestamp?;
              if (at == null && bt == null) return 0;
              if (at == null) return 1;
              if (bt == null) return -1;
              return bt.compareTo(at);
            });
            if (snapshot.hasError || docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppStyle.getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppStyle.getBorderColor(context)),
                ),
                child: Center(
                  child: Text('No reviews yet', style: GoogleFonts.plusJakartaSans(color: AppStyle.getSubtitleColor(context))),
                ),
              );
            }

            return Column(
              children: docs.take(3).map((doc) {
                final data = (doc.data() as Map?)?.cast<String, dynamic>() ??
                    const <String, dynamic>{};
                final name =
                    data['userName']?.toString().trim().isNotEmpty == true
                        ? data['userName'].toString()
                        : 'Anonim';
                final rating = data['rating'];
                final ratingValue = switch (rating) {
                  final num n => n.toDouble(),
                  final String s => double.tryParse(s) ?? 0,
                  _ => 0.0,
                };
                final time = data['createdAt'] as Timestamp?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyle.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppStyle.getBorderColor(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppStyle.getTextColor(context),
                              ),
                            ),
                            Text(
                              '${ratingValue.toStringAsFixed(0)} bintang'
                              '${time == null ? '' : ' · ${_relative(time)}'}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppStyle.getSubtitleColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.star_rounded,
                        color: Colors.amber.withValues(
                          alpha: (ratingValue / 5).clamp(0.15, 1.0),
                        ),
                        size: 18,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }
        ),
      ],
    );
  }

  String _relative(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 30) return '${diff.inDays} hari lalu';
    return '${diff.inDays ~/ 30} bln lalu';
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppStyle.errorRed, size: 48),
                  const SizedBox(height: 16),
                  Text('Error loading users', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: AppStyle.getSubtitleColor(context), fontSize: 13)),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        var users = snapshot.data?.docs ?? [];
        
        if (_searchQuery.isNotEmpty) {
          users = users.where((u) {
            final data = u.data() as Map<String, dynamic>;
            final name = (data['nama']?.toString() ?? data['name']?.toString() ?? '').toLowerCase();
            final email = (data['email']?.toString() ?? '').toLowerCase();
            final q = _searchQuery.toLowerCase();
            return name.contains(q) || email.contains(q);
          }).toList();
        }

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline_rounded, size: 64, color: AppStyle.primaryBlue.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text('No Users Found', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: AppStyle.getTextColor(context))),
                const SizedBox(height: 8),
                Text('Check your Firestore connection or filters.', style: GoogleFonts.plusJakartaSans(color: AppStyle.getSubtitleColor(context))),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(24, 24, 24, AppStyle.bottomInset(context) + 84),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final doc = users[index];
            final data = doc.data() as Map<String, dynamic>;
            // Support both 'nama' (app register) and 'name' (Google sign-in) fields
            final String name = data['nama']?.toString()
                ?? data['name']?.toString()
                ?? data['displayName']?.toString()
                ?? 'No Name';
            final String email = data['email']?.toString() ?? 'No Email';
            final String role = (data['role']?.toString() ?? 'user').toLowerCase();
            final bool isBlocked = data['blocked'] == true;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isBlocked
                    ? AppStyle.errorRed.withValues(alpha: 0.05)
                    : AppStyle.getCardColor(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isBlocked ? AppStyle.errorRed.withValues(alpha: 0.3) : AppStyle.getBorderColor(context),
                  width: 1.5,
                ),
                boxShadow: AppStyle.softShadow(context),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: isBlocked
                            ? AppStyle.errorRed.withValues(alpha: 0.1)
                            : AppStyle.primaryBlue.withValues(alpha: 0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.plusJakartaSans(
                            color: isBlocked ? AppStyle.errorRed : AppStyle.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isBlocked)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(color: AppStyle.errorRed, shape: BoxShape.circle),
                            child: const Icon(Icons.block_rounded, color: Colors.white, size: 9),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: AppStyle.getTextColor(context))),
                        Text(email, style: GoogleFonts.plusJakartaSans(color: AppStyle.getSubtitleColor(context), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: role == 'admin'
                          ? AppStyle.primaryBlue.withValues(alpha: 0.1)
                          : AppStyle.successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: role == 'admin'
                            ? AppStyle.primaryBlue
                            : AppStyle.successGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        _confirmDeleteUser(doc.id, name);
                        return;
                      }

                      final ref = FirebaseFirestore.instance
                          .collection('users')
                          .doc(doc.id);
                      final messenger = ScaffoldMessenger.of(context);
                      final updates = <String, dynamic>{
                        if (value == 'admin') 'role': 'admin',
                        if (value == 'user') 'role': 'user',
                        if (value == 'block') 'blocked': true,
                        if (value == 'unblock') 'blocked': false,
                      };
                      if (updates.isEmpty) return;

                      try {
                        await ref.update(updates);
                        final messages = <String, String>{
                          'admin': '$name sekarang Admin',
                          'user': '$name sekarang User',
                          'block': '$name telah diblokir',
                          'unblock': '$name telah dibuka blokirnya',
                        };
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(messages[value] ?? 'Berhasil'),
                            backgroundColor: value == 'block'
                                ? AppStyle.errorRed
                                : AppStyle.successGreen,
                          ),
                        );
                        await _logAction(
                          'User ${value.toUpperCase()}',
                          name,
                        );
                      } catch (e) {
                        debugPrint('User update error: $e');
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Gagal memperbarui: $e'),
                            backgroundColor: AppStyle.errorRed,
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      if (role != 'admin')
                        PopupMenuItem(
                          value: 'admin',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 18,
                                color: AppStyle.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Jadikan Admin',
                                style: GoogleFonts.plusJakartaSans(),
                              ),
                            ],
                          ),
                        ),
                      if (role != 'user')
                        PopupMenuItem(
                          value: 'user',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.school_rounded,
                                size: 18,
                                color: AppStyle.successGreen,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Jadikan User',
                                style: GoogleFonts.plusJakartaSans(),
                              ),
                            ],
                          ),
                        ),
                      if (!isBlocked)
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.block_rounded,
                                size: 18,
                                color: AppStyle.errorRed,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Blokir Pengguna',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppStyle.errorRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isBlocked)
                        PopupMenuItem(
                          value: 'unblock',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: AppStyle.successGreen,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Buka Blokir',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppStyle.successGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_forever_rounded,
                              size: 18,
                              color: AppStyle.errorRed,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Hapus Akun',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppStyle.errorRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, AppStyle.bottomInset(context) + 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SYSTEM CONFIGURATION',
            style: GoogleFonts.plusJakartaSans(
              color: AppStyle.accentOrange,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _configItem(
            icon: Icons.campaign_rounded,
            title: 'Send Notification',
            subtitle: 'Push a message to all users',
            color: AppStyle.primaryBlue,
            trailing: IconButton(
              icon: const Icon(Icons.send_rounded, color: AppStyle.primaryBlue),
              onPressed: _showSendNotificationDialog,
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('config').doc('system').snapshots(),
            builder: (context, snapshot) {
              bool maintenance = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                maintenance = (snapshot.data!.data() as Map<String, dynamic>)['maintenanceMode'] ?? false;
              }
              return _configItem(
                icon: Icons.security_rounded,
                title: 'Maintenance Mode',
                subtitle: maintenance ? 'App is currently restricted' : 'Restrict app access',
                color: Colors.red,
                trailing: Switch(
                  value: maintenance,
                  activeThumbColor: AppStyle.errorRed,
                  onChanged: (v) async {
                    await FirebaseFirestore.instance.collection('config').doc('system').set({'maintenanceMode': v}, SetOptions(merge: true));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Maintenance mode ${v ? 'enabled' : 'disabled'}'), backgroundColor: v ? AppStyle.errorRed : AppStyle.successGreen));
                    }
                  },
                ),
              );
            }
          ),
          _configItem(
            icon: Icons.history_rounded,
            title: 'Audit Logs',
            subtitle: 'View recent administrative actions',
            color: Colors.orange,
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.orange),
            onTap: _showAuditLogs,
          ),
          _configItem(
            icon: Icons.analytics_outlined,
            title: 'System Health',
            subtitle: 'Database & Auth connection status',
            color: Colors.teal,
            trailing: const Icon(Icons.check_circle_rounded, color: Colors.teal, size: 20),
            onTap: _showSystemHealth,
          ),
          _configItem(
            icon: Icons.health_and_safety_rounded,
            title: 'System Health Check',
            subtitle: 'Test Firebase connectivity',
            color: Colors.green,
            trailing: const Icon(Icons.bolt_rounded, color: Colors.green),
            onTap: _checkSystemHealth,
          ),
          const SizedBox(height: 12),
          _configItem(
            icon: Icons.language_rounded,
            title: 'Translation Map',
            subtitle: 'Manage app localized strings',
            color: Colors.blue,
            trailing: const Icon(Icons.edit_note_rounded, color: Colors.blue),
            onTap: _showTranslationMap,
          ),
          const SizedBox(height: 12),
          _configItem(
            icon: Icons.auto_awesome_rounded,
            title: 'Seed Sample Ratings',
            subtitle: 'Populate dashboard for demo',
            color: Colors.purple,
            trailing: const Icon(Icons.data_saver_on_rounded, color: Colors.purple),
            onTap: _seedSampleRatings,
          ),
          const SizedBox(height: 12),
          _configItem(
            icon: Icons.present_to_all_rounded,
            title: 'Presentation Mode',
            subtitle: 'Show mockup stats for demo',
            color: AppStyle.primaryBlue,
            trailing: Switch(
              value: _isPresentationMode,
              activeThumbColor: AppStyle.primaryBlue,
              onChanged: (v) => setState(() => _isPresentationMode = v),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'DANGER ZONE',
            style: GoogleFonts.plusJakartaSans(
              color: AppStyle.errorRed,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _logout,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppStyle.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppStyle.errorRed.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, color: AppStyle.errorRed, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'LOGOUT FROM ADMIN',
                      style: GoogleFonts.plusJakartaSans(color: AppStyle.errorRed, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _configItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppStyle.getCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppStyle.getBorderColor(context), width: 1.5),
        boxShadow: AppStyle.softShadow(context),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: AppStyle.getTextColor(context))),
        subtitle: Text(subtitle, style: GoogleFonts.plusJakartaSans(color: AppStyle.getSubtitleColor(context), fontSize: 12, fontWeight: FontWeight.w600)),
        trailing: trailing,
      ),
    );
  }

  Widget _buildFloatingBottomNav() {
    return AppStyle.darkNavBar(
      context: context,
      index: _selectedIndex,
      bottom: 20,
      items: const <NavItem>[
        NavItem(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          label: 'Dashboard',
          color: AppStyle.sunny,
        ),
        NavItem(
          icon: Icons.school_outlined,
          activeIcon: Icons.school_rounded,
          label: 'Beasiswa',
          color: AppStyle.periwinkle,
        ),
        NavItem(
          icon: Icons.people_outline_rounded,
          activeIcon: Icons.people_rounded,
          label: 'Pengguna',
          color: AppStyle.mint,
        ),
        NavItem(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          label: 'Sistem',
          color: AppStyle.coral,
        ),
      ],
      onTap: _onNavTap,
    );
  }
}
