import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/galat_api.dart';
import '../../core/config/batas_masukan.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/router/app_router.dart';
import '../../domain/models/app_user.dart';
import '../dev/pengalih_akun.dart';
import 'ganti_nomor_hp_dialog.dart';

/// Profil: siapa yang sedang masuk, pengaturan akun, dan jalan keluar dari akunnya.
///
/// Menggunakan desain Aloha Gojek yang konsisten dengan layar lainnya di aplikasi:
/// header hijau Gojek yang tegas, kartu identitas bersih berbingkai halus,
/// navigasi menu cepat dengan ikon badges pastel, formulir ubah data diri elegan,
/// dan tombol keluar bergaya modern.
class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userAktifProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00AA13),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Profil',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _KartuIdentitas(user: user),
                if (user.isKlien) ...[
                  const SizedBox(height: 14),
                  const _KartuRiwayat(),
                ],
                const SizedBox(height: 14),
                const _KartuPengaturan(),
                const SizedBox(height: 14),
                const KartuGantiAkun(),
                const SizedBox(height: 14),
                _KartuSunting(key: ValueKey(user.id), user: user),
                const SizedBox(height: 24),
                _TombolKeluar(nama: user.nama),
              ],
            ),
    );
  }
}

class _KartuIdentitas extends StatelessWidget {
  const _KartuIdentitas({required this.user});

  static const kunci = ValueKey('kartu-identitas');

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: kunci,
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFEDF2ED), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 60,
                  width: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00AA13), Color(0xFF00880C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00AA13).withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    user.nama.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nama,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E2124),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_iphone_rounded,
                            size: 14,
                            color: Color(0xFF00AA13),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.noHp,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final peran in user.peranMobile)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFC8E6C9),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          peran.label.toLowerCase().contains('runner')
                              ? Icons.two_wheeler_rounded
                              : Icons.person_rounded,
                          size: 13,
                          color: const Color(0xFF00880C),
                        ),
                        const SizedBox(width: 4.5),
                        Text(
                          peran.label,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00880C),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (user.alamat != null && user.alamat!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEDF2ED), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 15,
                      color: Color(0xFFFF7043),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user.alamat!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KartuRiwayat extends StatelessWidget {
  const _KartuRiwayat();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEDF2ED), width: 1.2),
      ),
      child: InkWell(
        onTap: () => context.push(Rute.riwayat),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF00AA13),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riwayat Order',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2124),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Lihat semua pesanan yang pernah kamu buat',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KartuPengaturan extends StatelessWidget {
  const _KartuPengaturan();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEDF2ED), width: 1.2),
      ),
      child: InkWell(
        onTap: () => context.push(Rute.pengaturan),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.settings_rounded,
                  color: Color(0xFFF97316),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2124),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kelola keamanan, password, dan preferensi akun',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TombolKeluar extends ConsumerStatefulWidget {
  const _TombolKeluar({required this.nama});

  final String nama;

  @override
  ConsumerState<_TombolKeluar> createState() => _TombolKeluarState();
}

class _TombolKeluarState extends ConsumerState<_TombolKeluar> {
  bool _sedangKeluar = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: _sedangKeluar ? null : _tanyaLaluKeluar,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFEF4444),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          elevation: 0,
        ),
        icon: _sedangKeluar
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.logout_rounded, size: 20),
        label: const Text(
          'Keluar',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Future<void> _tanyaLaluKeluar() async {
    final jadi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Keluar dari akun?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Kamu masuk sebagai ${widget.nama}. Untuk masuk lagi, kamu perlu '
          'menunggu kode yang dikirim ke nomor HP-mu.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (jadi != true || !mounted) return;

    setState(() => _sedangKeluar = true);
    try {
      await ref.read(authRepositoryProvider).keluar();
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangKeluar = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi
                  ? galat.pesan
                  : 'Gagal keluar. Terjadi kendala sambungan atau server.',
            ),
          ),
        );
      return;
    }
  }
}

class _KartuSunting extends ConsumerStatefulWidget {
  const _KartuSunting({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<_KartuSunting> createState() => _KartuSuntingState();
}

class _KartuSuntingState extends ConsumerState<_KartuSunting> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  late final TextEditingController _alamatController;
  bool _sedangSimpan = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.user.nama);
    _alamatController = TextEditingController(text: widget.user.alamat ?? '');
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  bool get _adaPerubahan =>
      _namaController.text.trim() != widget.user.nama ||
      _alamatController.text.trim() != (widget.user.alamat ?? '');

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFEDF2ED), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      color: Color(0xFF00AA13),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DATA DIRI',
                          style: TextStyle(
                            color: Color(0xFF00AA13),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ubah data diri',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2124),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _namaController,
                maxLength: BatasMasukan.nama,
                textCapitalization: TextCapitalization.words,
                enabled: !_sedangSimpan,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E2124),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Nama',
                  labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                  helperText: 'Ini yang dilihat runner saat menerima ordermu.',
                  helperStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF00AA13),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF00AA13),
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFEF4444)),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFEF4444),
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (nilai) => (nilai ?? '').trim().isEmpty
                    ? 'Nama tidak boleh kosong'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _alamatController,
                maxLength: BatasMasukan.alamat,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                minLines: 1,
                enabled: !_sedangSimpan,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E2124),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Alamat kosmu (boleh dikosongkan)',
                  labelStyle: const TextStyle(color: Color(0xFF6B7280)),
                  hintText: 'Kos Melati kamar 7, Jl. Pondok Labu Raya',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                  ),
                  helperText:
                      'Dipakai mengisi sendiri formulir order. Tetap bisa '
                      'diganti per order.',
                  helperStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.home_outlined,
                    color: Color(0xFF00AA13),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF00AA13),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_iphone_rounded,
                      color: Color(0xFF00AA13),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nomor HP: ${widget.user.noHp}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _sedangSimpan ? null : _gantiNomor,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF00880C),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Ganti nomor HP',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _sedangSimpan || !_adaPerubahan ? null : _simpan,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00AA13),
                    disabledBackgroundColor: const Color(0xFFE2E8E2),
                    disabledForegroundColor: const Color(0xFF8F9B91),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 0,
                  ),
                  icon: _sedangSimpan
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text(
                    'Simpan',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
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

  Future<void> _simpan() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sedangSimpan = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .perbaruiProfil(
            nama: _namaController.text,
            alamat: _alamatController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profil tersimpan.')));
    } catch (galat) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi
                  ? galat.pesan
                  : 'Gagal menyimpan. Terjadi kendala sambungan atau server.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _sedangSimpan = false);
    }
  }

  Future<void> _gantiNomor() async {
    final hasil = await showDialog<AppUser>(
      context: context,
      builder: (context) => GantiNomorHpDialog(noHpSekarang: widget.user.noHp),
    );

    if (hasil == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Nomor HP diganti ke ${hasil.noHp}.')),
      );
  }
}
