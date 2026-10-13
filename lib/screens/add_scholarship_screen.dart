import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/app_style.dart';

/// Add / edit a scholarship (admin only).
class AddScholarshipScreen extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>>? scholarshipDoc;

  const AddScholarshipScreen({super.key, this.scholarshipDoc});

  bool get isEditing => scholarshipDoc != null;

  @override
  State<AddScholarshipScreen> createState() => _AddScholarshipScreenState();
}

class _AddScholarshipScreenState extends State<AddScholarshipScreen> {
  static const List<String> _levels = ['S1', 'S2', 'S3', 'S2/S3', 'S1/S2/S3'];
  static const List<String> _fundingTypes = [
    'Full Funded',
    'Partial',
    'Self-Funded',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _countryController;
  late final TextEditingController _universityController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _requirementsController;
  late final TextEditingController _linkController;

  String _selectedLevel = 'S1';
  String _selectedFunding = 'Full Funded';
  DateTime? _selectedDeadline;
  bool _isFeatured = false;
  bool _isSaving = false;
  bool _showValidation = false;

  @override
  void initState() {
    super.initState();

    final data = widget.scholarshipDoc?.data();
    _nameController = TextEditingController(
      text: data?['title']?.toString() ?? '',
    );
    _countryController = TextEditingController(
      text: data?['country']?.toString() ?? '',
    );

    // The stored subtitle has the shape "<University> · <Country>".
    final subtitle = data?['subtitle']?.toString() ?? '';
    _universityController = TextEditingController(
      text: subtitle.contains('·') ? subtitle.split('·').first.trim() : subtitle,
    );
    _descriptionController = TextEditingController(
      text: data?['description']?.toString() ?? '',
    );
    _requirementsController = TextEditingController(
      text: data?['requirements']?.toString() ?? '',
    );
    _linkController = TextEditingController(
      text: data?['url']?.toString() ?? '',
    );

    if (data != null) {
      // Bug fix: `DropdownButton` asserts its value is present in `items`;
      // unknown stored values used to crash the screen.
      final level = data['level']?.toString();
      _selectedLevel = _levels.contains(level) ? level! : 'S1';

      final funding = data['funding']?.toString();
      _selectedFunding = _fundingTypes.contains(funding) ? funding! : 'Full Funded';

      _isFeatured = data['isFeatured'] == true;
      _selectedDeadline = _parseDeadline(data['deadline']?.toString());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _universityController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  static DateTime? _parseDeadline(String? raw) {
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'varies') {
      return null;
    }
    for (final pattern in ['MMM yyyy', 'dd MMM yyyy', 'yyyy-MM-dd']) {
      try {
        return DateFormat(pattern).parseStrict(raw);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // ─────────────────────────── deadline ───────────────────────────
  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1);
    final last = DateTime(now.year + 10);

    // Bug fix: `initialDate` must sit inside [firstDate, lastDate]; the old code
    // always used `DateTime.now()`, which threw while editing a past deadline.
    final requested = _selectedDeadline ?? now.add(const Duration(days: 30));
    final initial = requested.isBefore(first)
        ? first
        : (requested.isAfter(last) ? last : requested);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );

    if (picked == null || !mounted) return;
    setState(() => _selectedDeadline = picked);
  }

  // ─────────────────────────── saving ───────────────────────────
  String? _validate() {
    if (_nameController.text.trim().isEmpty) {
      return 'Nama beasiswa wajib diisi.';
    }
    if (_countryController.text.trim().isEmpty) {
      return 'Negara wajib diisi.';
    }
    final url = _linkController.text.trim();
    if (url.isNotEmpty && !url.startsWith('http')) {
      return 'URL harus diawali http:// atau https://';
    }
    return null;
  }

  Future<void> _saveScholarship() async {
    setState(() => _showValidation = true);

    final error = _validate();
    if (error != null) {
      _toast(error, AppStyle.errorRed);
      return;
    }

    setState(() => _isSaving = true);

    final country = _countryController.text.trim();
    final university = _universityController.text.trim();
    final deadlineStr = _selectedDeadline == null
        ? 'Varies'
        : DateFormat('MMM yyyy').format(_selectedDeadline!);

    final payload = <String, dynamic>{
      'title': _nameController.text.trim(),
      'country': country,
      'subtitle': university.isEmpty ? country : '$university · $country',
      'level': _selectedLevel,
      'funding': _selectedFunding,
      'deadline': deadlineStr,
      'url': _linkController.text.trim().isEmpty
          ? 'https://www.google.com/search?q=${Uri.encodeQueryComponent(_nameController.text.trim())}'
          : _linkController.text.trim(),
      'description': _descriptionController.text.trim(),
      'requirements': _requirementsController.text.trim(),
      'flag': widget.scholarshipDoc?.data()?['flag']?.toString() ?? '🌍',
      'isFeatured': _isFeatured,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final collection = FirebaseFirestore.instance.collection('scholarships');

      if (widget.isEditing) {
        // Bug fix: `update()` throws NOT_FOUND if the doc was removed;
        // `set(..., merge: true)` is idempotent.
        await collection
            .doc(widget.scholarshipDoc!.id)
            .set(payload, SetOptions(merge: true));
      } else {
        await collection.add(<String, dynamic>{
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.pop(context);
      _toast(
        widget.isEditing ? 'Beasiswa diperbarui.' : 'Beasiswa dipublikasikan.',
        AppStyle.successGreen,
      );
    } catch (e) {
      debugPrint('Save scholarship error: $e');
      if (!mounted) return;
      _toast('Gagal menyimpan: $e', AppStyle.errorRed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────────────────── form fields ───────────────────────────
  Widget _buildField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hint,
    bool required = false,
  }) {
    final error =
        (_showValidation && required && controller.text.trim().isEmpty)
            ? '$label wajib diisi'
            : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AppStyle.getSubtitleColor(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.plusJakartaSans(
              color: AppStyle.getTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              errorText: error,
              hintStyle: GoogleFonts.plusJakartaSans(
                color: AppStyle.getSubtitleColor(
                  context,
                ).withValues(alpha: 0.55),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AppStyle.getSubtitleColor(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(16),
            dropdownColor: AppStyle.getCardColor(context),
            style: GoogleFonts.plusJakartaSans(
              color: AppStyle.getTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            items: items
                .map(
                  (i) => DropdownMenuItem<String>(
                    value: i,
                    child: Text(i),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── build ───────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: Column(
        children: [
          AppHeaders.pageHeader(
            context: context,
            title: widget.isEditing ? 'Edit Beasiswa' : 'Tambah Beasiswa',
            subtitle: 'Manajemen Konten',
            leading: AppStyle.circleButton(
              context: context,
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
              size: 42,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('INFORMASI DASAR'),
                  _buildField(
                    'Nama Beasiswa',
                    _nameController,
                    hint: 'Contoh: Chevening Scholarship',
                    required: true,
                  ),
                  _buildField(
                    'Negara',
                    _countryController,
                    hint: 'Contoh: United Kingdom',
                    required: true,
                  ),
                  _buildField(
                    'Universitas / Organisasi',
                    _universityController,
                    hint: 'Contoh: Oxford University',
                  ),

                  const _SectionLabel('PERSYARATAN & PENDANAAN'),
                  _buildDropdown(
                    'Jenjang Pendidikan',
                    _selectedLevel,
                    _levels,
                    (v) => setState(() => _selectedLevel = v),
                  ),
                  _buildDropdown(
                    'Jenis Beasiswa',
                    _selectedFunding,
                    _fundingTypes,
                    (v) => setState(() => _selectedFunding = v),
                  ),

                  const _SectionLabel('DEADLINE PENDAFTARAN'),
                  _buildDeadlinePicker(),

                  const _SectionLabel('DETAIL TAMBAHAN'),
                  _buildField(
                    'Deskripsi',
                    _descriptionController,
                    maxLines: 4,
                  ),
                  _buildField(
                    'Persyaratan',
                    _requirementsController,
                    maxLines: 4,
                  ),
                  _buildField(
                    'Situs Resmi',
                    _linkController,
                    hint: 'https://...',
                  ),

                  _buildFeaturedToggle(),
                  const SizedBox(height: 8),
                  Text(
                    'Beasiswa unggulan akan tampil di carousel atas untuk semua '
                    'pengguna.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppStyle.getSubtitleColor(context),
                      fontSize: 11.5,
                    ),
                  ),

                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveScholarship,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyle.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              widget.isEditing
                                  ? 'Simpan Perubahan'
                                  : 'Publikasikan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
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

  Widget _buildFeaturedToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppStyle.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppStyle.getBorderColor(context)),
      ),
      child: Row(
        children: [
          Switch(
            value: _isFeatured,
            activeThumbColor: AppStyle.primaryBlue,
            onChanged: (v) => setState(() => _isFeatured = v),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Jadikan unggulan',
              style: GoogleFonts.plusJakartaSans(
                color: AppStyle.getTextColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const Icon(
            Icons.stars_rounded,
            color: AppStyle.accentOrange,
            size: 17,
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildDeadlinePicker() {
    final label = _selectedDeadline == null
        ? 'Pilih deadline'
        : DateFormat('dd MMM yyyy').format(_selectedDeadline!);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _selectDeadline,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: const InputDecoration(
            prefixIcon: Icon(
              Icons.calendar_today_rounded,
              color: AppStyle.primaryBlue,
              size: 19,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _selectedDeadline == null
                        ? AppStyle.getSubtitleColor(context)
                        : AppStyle.getTextColor(context),
                  ),
                ),
              ),
              if (_selectedDeadline != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedDeadline = null),
                  child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
              color: AppStyle.accentOrange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: AppStyle.accentOrange,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
