import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_style.dart';
import '../widgets/scholarship_card.dart';
import 'add_scholarship_screen.dart';

class ManageScholarshipsScreen extends StatefulWidget {
  const ManageScholarshipsScreen({super.key});

  @override
  State<ManageScholarshipsScreen> createState() =>
      _ManageScholarshipsScreenState();
}

class _ManageScholarshipsScreenState extends State<ManageScholarshipsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteScholarship(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppStyle.getCardColor(ctx),
        title: Text(
          'Hapus Beasiswa?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppStyle.getTextColor(ctx),
          ),
        ),
        content: Text(
          'Tindakan ini tidak dapat dibatalkan.',
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
                color: AppStyle.primaryBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyle.errorRed,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Hapus',
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

    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('scholarships')
          .doc(docId)
          .delete();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Beasiswa dihapus.'),
          backgroundColor: AppStyle.successGreen,
        ),
      );
    } catch (e) {
      debugPrint('Delete scholarship error: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus: $e'),
          backgroundColor: AppStyle.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: Column(
        children: [
          AppHeaders.pageHeader(
            context: context,
            title: 'Kelola Beasiswa',
            subtitle: 'Manajemen Konten',
            showSearch: true,
            searchController: _searchController,
            searchHint: 'Cari beasiswa...',
            onSearchChanged: (v) => setState(() => _query = v.toLowerCase()),
            onSearchCleared: () => setState(() => _query = ''),
            leading: AppStyle.circleButton(
              context: context,
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
              size: 42,
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // Bug fix: `orderBy('createdAt')` silently dropped every document
              // that lacks the field (and failed outright without an index).
              // Sorting happens in memory instead.
              stream: FirebaseFirestore.instance
                  .collection('scholarships')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final remote = <Map<String, dynamic>>[];
                for (final doc in snapshot.data?.docs ?? const []) {
                  final data = doc.data();
                  if (data.isEmpty) continue;
                  remote.add(<String, dynamic>{
                    ...data,
                    'id': doc.id,
                    'doc': doc,
                    'isDefault': false,
                  });
                }
                remote.sort(
                  (a, b) => ScholarshipCard.titleOf(
                    a,
                  ).compareTo(ScholarshipCard.titleOf(b)),
                );

                final items = remote.where((s) {
                  if (_query.isEmpty) return true;
                  return ScholarshipCard.titleOf(
                        s,
                      ).toLowerCase().contains(_query) ||
                      ScholarshipCard.countryOf(
                        s,
                      ).toLowerCase().contains(_query);
                }).toList(growable: false);

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 56,
                          color: AppStyle.primaryBlue.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Belum ada beasiswa dibuat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppStyle.getTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ketuk tombol + untuk menambah beasiswa baru.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: AppStyle.getSubtitleColor(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                  itemCount: items.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ManageCard(
                      data: items[index],
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddScholarshipScreen(
                            scholarshipDoc: items[index]['doc']
                                as DocumentSnapshot<Map<String, dynamic>>,
                          ),
                        ),
                      ),
                      onDelete: () => _deleteScholarship(
                        items[index]['id']?.toString() ?? '',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddScholarshipScreen()),
        ),
        backgroundColor: AppStyle.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Tambah',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ManageCard({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppStyle.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppStyle.getBorderColor(context), width: 1.2),
        boxShadow: AppStyle.softShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppStyle.secondaryBlue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Text(
              ScholarshipCard.flagOf(data),
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ScholarshipCard.titleOf(data),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppStyle.getTextColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ScholarshipCard.countryOf(data)} · ${ScholarshipCard.levelOf(data)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppStyle.getSubtitleColor(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(
              Icons.edit_rounded,
              color: AppStyle.primaryBlue,
              size: 20,
            ),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Hapus',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppStyle.errorRed,
              size: 20,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
