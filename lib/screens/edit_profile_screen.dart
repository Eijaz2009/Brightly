import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/app_style.dart';
import '../services/phone_auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  const EditProfileScreen({super.key, required this.currentName});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  final _schoolController = TextEditingController();
  final _birthDateController = TextEditingController();
  DateTime? _selectedBirthDate;
  bool _isLoading = false;

  /// Nomor HP yang sudah tertaut di Firebase Auth (sumber kebenaran).
  String _linkedPhone = '';
  bool _isLinkingPhone = false;

  /// Mirrors [_birthDateController.text] so the date row can rebuild.
  String _birthDateText = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _birthDateController.addListener(() {
      if (_birthDateController.text == _birthDateText) return;
      setState(() => _birthDateText = _birthDateController.text);
    });
    _loadExistingData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Ambil nama dari Firebase Auth jika widget.currentName kosong
      if (widget.currentName.isNotEmpty && _nameController.text.isEmpty) {
        _nameController.text = widget.currentName;
      } else if (_nameController.text.isEmpty && user.displayName != null) {
        _nameController.text = user.displayName!;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;
      setState(() {
        _linkedPhone = user.phoneNumber ?? '';
        if (!doc.exists) return;
        final data = doc.data();
        if (data == null) return;

        // Nama: dukung 'nama' atau 'name' dari Firestore jika ada
        final firestoreName = data['nama']?.toString() ?? data['name']?.toString() ?? '';
        if (firestoreName.isNotEmpty && _nameController.text.isEmpty) {
          _nameController.text = firestoreName;
        }

        // Sekolah: dukung 'school' atau 'sekolah'
        final school = data['school']?.toString() ?? data['sekolah']?.toString() ?? '';
        _schoolController.text = school;

        // Tanggal Lahir: dukung 'birthDate', 'tanggalLahir', atau 'birth'
        final birth = data['birthDate']?.toString() ?? 
                      data['tanggalLahir']?.toString() ?? 
                      data['birth']?.toString() ?? '';
        _birthDateController.text = birth;
        _selectedBirthDate = _parseBirthDate(birth);
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  /// Tries to parse the stored value so the picker opens on the right date.
  static DateTime? _parseBirthDate(String raw) {
    if (raw.isEmpty) return null;
    for (final pattern in ['dd MMM yyyy', 'yyyy-MM-dd', 'dd/MM/yyyy']) {
      try {
        return DateFormat(pattern).parseStrict(raw);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppStyle.primaryBlue,
            primary: AppStyle.primaryBlue,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedBirthDate = picked;
      _birthDateController.text = DateFormat('dd MMM yyyy').format(picked);
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length < 2) {
      _toast('Nama minimal 2 karakter.', AppStyle.errorRed);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('Sesi tidak ditemukan. Silakan masuk kembali.', AppStyle.errorRed);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await user.updateDisplayName(name);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(<String, dynamic>{
            'nama': name,
            'name': name,
            'school': _schoolController.text.trim(),
            'birthDate': _birthDateController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Save profile error: $e');
      if (!mounted) return;
      _toast('Gagal memperbarui profil: $e', AppStyle.errorRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  /// Menautkan nomor HP ke akun (syarat agar OTP lupa-password bisa dipakai).
  /// Alur: input nomor → kirim OTP → input OTP → link.
  Future<void> _linkPhoneNumber() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('Sesi tidak ditemukan. Silakan masuk kembali.', AppStyle.errorRed);
      return;
    }

    // Langkah 1: minta nomor.
    final phoneController = TextEditingController(
      text: _linkedPhone.isNotEmpty ? _linkedPhone : '',
    );
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tautkan nomor HP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nomor ini dipakai untuk menerima OTP saat lupa password.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '0812xxxxxxx',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, phoneController.text.trim()),
            child: const Text('Kirim OTP'),
          ),
        ],
      ),
    );
    phoneController.dispose();
    if (phone == null || phone.isEmpty || !mounted) return;

    final phoneError = PhoneAuthService.validatePhone(phone);
    if (phoneError != null) {
      _toast(phoneError, AppStyle.errorRed);
      return;
    }
    final normalized = PhoneAuthService.normalizePhone(phone)!;

    // Langkah 2: kirim OTP, lalu minta kodenya.
    // Di Android, verifikasi bisa otomatis (auto-retrieval) sehingga
    // `onCodeSent` tidak dipanggil — `verificationId` diambil dari timeout.
    setState(() => _isLinkingPhone = true);
    String? verificationId;
    String? sendError;
    bool autoLinked = false;
    await PhoneAuthService.sendVerificationCode(
      phoneNumber: normalized,
      onAutoVerified: (credential) async {
        final result = await PhoneAuthService.linkCredential(
          credential,
          phoneNumber: normalized,
        );
        if (!mounted) return;
        if (result.success) autoLinked = true;
      },
      onCodeSent: (id, _) => verificationId = id,
      onFailed: (message) => sendError = message,
      onAutoRetrievalTimeout: (id) => verificationId = id,
    );
    if (!mounted) return;
    setState(() => _isLinkingPhone = false);

    if (autoLinked) {
      setState(
        () =>
            _linkedPhone =
                FirebaseAuth.instance.currentUser?.phoneNumber ?? normalized,
      );
      _toast('Nomor HP berhasil ditautkan.', AppStyle.mint);
      return;
    }

    if (sendError != null || verificationId == null) {
      _toast(sendError ?? 'Gagal mengirim OTP.', AppStyle.errorRed);
      return;
    }

    final otpController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Masukkan kode OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kode 6 digit dikirim ke $normalized.'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              decoration: const InputDecoration(
                hintText: '••••••',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, otpController.text.trim()),
            child: const Text('Tautkan'),
          ),
        ],
      ),
    );
    otpController.dispose();
    if (code == null || code.isEmpty || !mounted) return;

    // Langkah 3: link kredensial ke akun.
    setState(() => _isLinkingPhone = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: code,
      );
      final result = await PhoneAuthService.linkCredential(
        credential,
        phoneNumber: normalized,
      );
      if (!mounted) return;
      if (result.success) {
        setState(
          () =>
              _linkedPhone =
                  FirebaseAuth.instance.currentUser?.phoneNumber ?? normalized,
        );
        _toast('Nomor HP berhasil ditautkan.', AppStyle.mint);
      } else {
        _toast(result.error ?? 'Gagal menautkan nomor.', AppStyle.errorRed);
      }
    } finally {
      if (mounted) setState(() => _isLinkingPhone = false);
    }
  }

  /// Melepas tautan nomor HP dari akun.
  Future<void> _unlinkPhoneNumber() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lepas nomor HP?'),
        content: const Text(
          'Setelah dilepas, OTP lupa-password tidak bisa dipakai sampai '
          'kamu menautkan nomor lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lepas'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isLinkingPhone = true);
    try {
      final result = await PhoneAuthService.unlinkPhone();
      if (!mounted) return;
      if (result.success) {
        setState(() => _linkedPhone = '');
        _toast('Nomor HP dilepas.', AppStyle.mint);
      } else {
        _toast(result.error ?? 'Gagal melepas nomor.', AppStyle.errorRed);
      }
    } finally {
      if (mounted) setState(() => _isLinkingPhone = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppStyle.getBackgroundColor(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              AppStyle.circleButton(
                context: context,
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
                size: 42,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit Profile',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppStyle.getTextColor(context),
                      ),
                    ),
                    Text(
                      'Perbarui informasi akunmu',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: AppStyle.getSubtitleColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildInputField('FULL NAME', _nameController, Icons.person_outline_rounded),
            const SizedBox(height: 20),
            _buildInputField('SCHOOL / UNIVERSITY', _schoolController, Icons.school_outlined),
            const SizedBox(height: 20),
            _buildDateField('TANGGAL LAHIR', Icons.calendar_today_outlined),
            const SizedBox(height: 20),
            _buildPhoneSection(),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyle.primaryBlue,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Text('Save Changes', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppStyle.accentOrange,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppStyle.getTextColor(context),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppStyle.primaryBlue, size: 20),
            hintText: 'Belum diisi',
            hintStyle: GoogleFonts.plusJakartaSans(
              color: AppStyle.getSubtitleColor(context).withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  /// Kartu status nomor HP + tombol tautkan/lepas.
  Widget _buildPhoneSection() {
    final linked = _linkedPhone.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOMOR HP (UNTUK OTP)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppStyle.accentOrange,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppStyle.getCardColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppStyle.getBorderColor(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (linked ? AppStyle.mint : AppStyle.sunny)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  linked
                      ? Icons.verified_rounded
                      : Icons.phone_outlined,
                  color: linked ? AppStyle.mint : AppStyle.sunny,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      linked ? _linkedPhone : 'Belum ditautkan',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppStyle.getTextColor(context),
                      ),
                    ),
                    Text(
                      linked
                          ? 'OTP lupa-password aktif untuk nomor ini.'
                          : 'Tautkan agar bisa reset password via OTP.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppStyle.getSubtitleColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLinkingPhone)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (linked)
                TextButton(
                  onPressed: _unlinkPhoneNumber,
                  child: const Text('Lepas'),
                )
              else
                ElevatedButton(
                  onPressed: _linkPhoneNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyle.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Tautkan'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, IconData icon) {    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppStyle.accentOrange,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickBirthDate,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: AppStyle.primaryBlue, size: 20),
                suffixIcon: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppStyle.getSubtitleColor(context),
                ),
              ),
              child: Text(
                _birthDateText.isEmpty ? 'Pilih tanggal lahir' : _birthDateText,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _birthDateText.isEmpty
                      ? AppStyle.getSubtitleColor(context)
                      : AppStyle.getTextColor(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
