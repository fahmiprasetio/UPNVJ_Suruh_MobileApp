import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/tindakan_terkelola.dart';
import '../../core/config/batas_masukan.dart';
import '../../core/format/validasi_kontak.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/router/app_router.dart';

/// Langkah autentikasi yang sedang aktif.
enum _Langkah { nomor, daftar, kode, password }

/// Layar Autentikasi Utama UPNVJ Suruh dengan Desain Modern Gojek Aloha.
///
/// Menyediakan alur masuk via nomor HP + OTP, registrasi akun baru mahasiswa,
/// verifikasi 6 digit OTP segmented box, dan login via password opsional.
class MasukScreen extends ConsumerStatefulWidget {
  const MasukScreen({super.key});

  @override
  ConsumerState<MasukScreen> createState() => _MasukScreenState();
}

class _MasukScreenState extends ConsumerState<MasukScreen>
    with TindakanTerkelola<MasukScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _noHpController = TextEditingController();
  final _kodeController = TextEditingController();
  final _passwordController = TextEditingController();

  _Langkah _langkah = _Langkah.nomor;
  bool _sembunyikanPassword = true;

  @override
  void dispose() {
    _namaController.dispose();
    _noHpController.dispose();
    _kodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validasiNama(String? nilai) {
    final bersih = (nilai ?? '').trim();
    if (bersih.isEmpty) return 'Nama lengkap belum diisi';
    if (bersih.length > BatasMasukan.nama) {
      return 'Nama maksimal ${BatasMasukan.nama} karakter';
    }
    return null;
  }

  Future<void> _kirimKode() => jalankan(_formKey, () async {
    await ref
        .read(authRepositoryProvider)
        .mintaKode(noHp: _noHpController.text.trim());
    if (mounted) setState(() => _langkah = _Langkah.kode);
  });

  Future<void> _daftarLaluKirimKode() => jalankan(_formKey, () async {
    final repo = ref.read(authRepositoryProvider);
    await repo.daftar(
      nama: _namaController.text.trim(),
      noHp: _noHpController.text.trim(),
    );
    await repo.mintaKode(noHp: _noHpController.text.trim());
    if (mounted) setState(() => _langkah = _Langkah.kode);
  });

  Future<void> _masuk() => jalankan(_formKey, () async {
    FocusScope.of(context).unfocus();
    await ref
        .read(authRepositoryProvider)
        .masuk(
          noHp: _noHpController.text.trim(),
          kode: _kodeController.text.trim(),
        );
    ref.read(sesiDitolakProvider.notifier).padamkan();
    ref.invalidate(userAktifProvider);
    if (mounted) {
      context.go(Rute.beranda);
    }
  });

  Future<void> _masukPassword() => jalankan(_formKey, () async {
    FocusScope.of(context).unfocus();
    await ref
        .read(authRepositoryProvider)
        .masukPassword(
          noHp: _noHpController.text.trim(),
          password: _passwordController.text,
        );
    ref.read(sesiDitolakProvider.notifier).padamkan();
    ref.invalidate(userAktifProvider);
    if (mounted) {
      context.go(Rute.beranda);
    }
  });

  void _kembaliKeNomor() {
    _kodeController.clear();
    _passwordController.clear();
    setState(() {
      _langkah = _Langkah.nomor;
      galatTindakan = null;
    });
  }

  void _keDaftar() {
    setState(() {
      _langkah = _Langkah.daftar;
      galatTindakan = null;
    });
  }

  void _kePassword() {
    setState(() {
      _langkah = _Langkah.password;
      galatTindakan = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. HERO HEADER ALOHA HIJAU GOJEK DENGAN LOGO LENCANA MASKOT
          const _PanelMerekAloha(),

          // 2. KARTU FORMULIR ALOHA
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // PEMBERITAHUAN SESI BERAKHIR
                        if (ref.watch(sesiDitolakProvider)) ...[
                          const _KotakGalatAloha.pemberitahuan(
                            pesan:
                                'Sesimu telah berakhir. Silakan masuk kembali, '
                                'seluruh data dan riwayat pesananmu tetap aman.',
                          ),
                          const SizedBox(height: 16),
                        ],

                        // PEMBERITAHUAN PENYIMPANAN
                        if (ref
                            .watch(sesiTokenProvider)
                            .penyimpananBermasalah) ...[
                          const _KotakGalatAloha(
                            pesan:
                                'Penyimpanan aman perangkat bermasalah. '
                                'Jangan gunakan perangkat publik/bersama.',
                          ),
                          const SizedBox(height: 16),
                        ],

                        // KONTEN SESUAI LANGKAH AKTIF
                        ..._bangunIsiLangkah(),

                        // KOTAK GALAT VALIDASI / SERVER
                        if (galatTindakan != null) ...[
                          const SizedBox(height: 16),
                          _KotakGalatAloha(pesan: galatTindakan!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _bangunIsiLangkah() {
    switch (_langkah) {
      case _Langkah.nomor:
        return [
          // Header Langkah Masuk
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F8EA),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.login_rounded,
                    color: Color(0xFF00AA13),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Masuk ke Akun',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Masukkan nomor HP untuk menerima kode OTP.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Kolom Nomor HP
          _kolomNoHp(autofocus: true),

          const SizedBox(height: 18),

          // Tombol Utama Kirim Kode Hijau Gojek
          _tombolUtamaAloha(
            label: 'Kirim Kode OTP',
            ikon: Icons.arrow_forward_rounded,
            aksi: _kirimKode,
          ),

          const SizedBox(height: 16),

          // Link Daftar Akun Baru
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Belum punya akun? ',
                style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
              ),
              InkWell(
                onTap: sedangMengirim ? null : _keDaftar,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Daftar Sekarang',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00880C),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Link Masuk Password
          Center(
            child: TextButton.icon(
              onPressed: sedangMengirim ? null : _kePassword,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
              ),
              icon: const Icon(Icons.lock_outline_rounded, size: 15),
              label: const Text(
                'Sudah atur password? Masuk pakai itu',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ];

      case _Langkah.daftar:
        return [
          // Header Langkah Daftar
          Row(
            children: [
              InkWell(
                onTap: sedangMengirim ? null : _kembaliKeNomor,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF374151),
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daftar Akun Baru',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Satu akun untuk pesan layanan & jadi runner.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Kolom Nama Lengkap
          TextFormField(
            controller: _namaController,
            maxLength: BatasMasukan.nama,
            buildCounter: (
              context, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) => null,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            decoration: InputDecoration(
              labelText: 'Nama Lengkap',
              hintText: 'Nama yang dipakai memanggilmu',
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF00AA13),
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF00AA13), width: 1.8),
              ),
            ),
            validator: _validasiNama,
          ),

          const SizedBox(height: 16),

          // Kolom Nomor HP
          _kolomNoHp(),

          const SizedBox(height: 18),

          // Tombol Daftar Hijau Gojek
          _tombolUtamaAloha(
            label: 'Daftar & Minta Kode',
            ikon: Icons.check_circle_outline_rounded,
            aksi: _daftarLaluKirimKode,
          ),

          const SizedBox(height: 16),

          // Link Kembali ke Masuk
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Sudah punya akun? ',
                style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
              ),
              InkWell(
                onTap: sedangMengirim ? null : _kembaliKeNomor,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Masuk di sini',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00880C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ];

      case _Langkah.kode:
        final noHp = _noHpController.text.trim();
        return [
          // Header Verifikasi OTP
          Row(
            children: [
              InkWell(
                onTap: sedangMengirim ? null : _kembaliKeNomor,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF374151),
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verifikasi Kode OTP',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Masukkan 6 angka yang dikirim ke nomor:',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pill Target Nomor HP dengan Aksi Ubah
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8EA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC6F6D5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sms_outlined,
                  size: 16,
                  color: Color(0xFF00880C),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    noHp,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF006C0E),
                    ),
                  ),
                ),
                InkWell(
                  onTap: sedangMengirim ? null : _kembaliKeNomor,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Ubah Nomor',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00880C),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Input OTP Segmented Display
          _KotakInputOtpAloha(
            controller: _kodeController,
            validator: validasiKode,
            onChanged: (val) {
              setState(() {});
              if (val.trim().length == 6 && !sedangMengirim) {
                _masuk();
              }
            },
          ),

          const SizedBox(height: 22),

          // Tombol Verifikasi Masuk
          _tombolUtamaAloha(
            label: 'Verifikasi & Masuk',
            ikon: Icons.lock_open_rounded,
            aksi: _masuk,
          ),

          const SizedBox(height: 16),

          // Aksi Kirim Ulang Kode OTP
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Tidak menerima kode? ',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                ),
                InkWell(
                  onTap: sedangMengirim ? null : _kirimKode,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'Kirim Ulang',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF00AA13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bantuan Nomor Belum Terdaftar
          _JalanKeluarBelumTerdaftarAloha(
            onDaftar: sedangMengirim ? null : _keDaftar,
          ),
        ];

      case _Langkah.password:
        return [
          Row(
            children: [
              InkWell(
                onTap: sedangMengirim ? null : _kembaliKeNomor,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF374151),
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Masuk via Password',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Masuk langsung tanpa menunggu kode SMS.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _kolomNoHp(),

          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: _sembunyikanPassword,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF00AA13),
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _sembunyikanPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF6B7280),
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _sembunyikanPassword = !_sembunyikanPassword,
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF00AA13), width: 1.8),
              ),
            ),
            validator: (nilai) =>
                (nilai == null || nilai.isEmpty) ? 'Password belum diisi' : null,
          ),

          const SizedBox(height: 18),

          _tombolUtamaAloha(
            label: 'Masuk dengan Password',
            ikon: Icons.lock_open_rounded,
            aksi: _masukPassword,
          ),

          const SizedBox(height: 12),

          Center(
            child: TextButton(
              onPressed: sedangMengirim ? null : _kembaliKeNomor,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00880C),
              ),
              child: const Text(
                'Masuk pakai kode OTP saja',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ];
    }
  }

  Widget _kolomNoHp({bool autofocus = false}) => TextFormField(
    controller: _noHpController,
    autofocus: autofocus,
    keyboardType: TextInputType.phone,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(BatasMasukan.nomorHp),
    ],
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Color(0xFF111827),
      letterSpacing: 0.5,
    ),
    decoration: InputDecoration(
      labelText: 'Nomor WhatsApp / HP',
      hintText: 'Contoh: 081234567890',
      prefixIcon: const Icon(
        Icons.phone_android_rounded,
        color: Color(0xFF00AA13),
        size: 20,
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF00AA13), width: 1.8),
      ),
    ),
    validator: validasiNoHp,
  );

  Widget _tombolUtamaAloha({
    required String label,
    required IconData ikon,
    required Future<void> Function() aksi,
  }) => SizedBox(
    height: 50,
    child: ElevatedButton(
      onPressed: sedangMengirim ? null : aksi,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00AA13),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF86EFAC),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: sedangMengirim
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(ikon, size: 18),
              ],
            ),
    ),
  );
}

/// Widget Input 6-Digit OTP Segmented Box Bergaya Gojek Aloha
class _KotakInputOtpAloha extends StatefulWidget {
  const _KotakInputOtpAloha({
    required this.controller,
    required this.validator,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String> onChanged;

  @override
  State<_KotakInputOtpAloha> createState() => _KotakInputOtpAlohaState();
}

class _KotakInputOtpAlohaState extends State<_KotakInputOtpAloha> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;

    return FormField<String>(
      validator: widget.validator,
      initialValue: text,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 6 Box Segmented Display di latar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      final hasChar = text.length > index;
                      final isCurrent = _focusNode.hasFocus &&
                          (text.length == index ||
                              (text.length == 6 && index == 5));

                      return Container(
                        width: 44,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFFE8F8EA)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? const Color(0xFF00AA13)
                                : hasChar
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFD1D5DB),
                            width: isCurrent ? 2 : 1.2,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00AA13)
                                        .withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            hasChar ? text[index] : '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  // Invisible textfield menutupi seluruh kotak untuk deteksi klik & ketikan alami di mobile web
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.0,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: (val) {
                          state.didChange(val);
                          widget.onChanged(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (state.hasError) ...[
              const SizedBox(height: 8),
              Text(
                state.errorText ?? '',
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Hero Banner Atas Aloha Gojek dengan Warna Hijau Terang dan Maskot
class _PanelMerekAloha extends StatelessWidget {
  const _PanelMerekAloha();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF00AA13), Color(0xFF007E0F)],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              // Logo Lencana Maskot Buaya
              Container(
                height: 96,
                width: 96,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/logo/lencana.png',
                  fit: BoxFit.contain,
                  cacheWidth: 256,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'UPNVJ Suruh',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Apa pun yang kamu suruh, kami usahakan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner Bantuan Nomor Belum Terdaftar
class _JalanKeluarBelumTerdaftarAloha extends StatelessWidget {
  const _JalanKeluarBelumTerdaftarAloha({required this.onDaftar});

  final VoidCallback? onDaftar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nomor belum terdaftar di sistem?',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Jika kode tidak kunjung masuk, nomor HP kamu mungkin belum didaftarkan.',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF6B7280),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onDaftar,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00880C),
              side: const BorderSide(color: Color(0xFF00AA13)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
            child: const Text(
              'Daftar Akun Baru Sekarang',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotak Galat Bergaya Aloha Modern
class _KotakGalatAloha extends StatelessWidget {
  const _KotakGalatAloha({required this.pesan}) : _salahPengguna = true;

  const _KotakGalatAloha.pemberitahuan({required this.pesan})
    : _salahPengguna = false;

  final String pesan;
  final bool _salahPengguna;

  @override
  Widget build(BuildContext context) {
    final latar = _salahPengguna ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF);
    final border = _salahPengguna ? const Color(0xFFFCA5A5) : const Color(0xFFBFDBFE);
    final tinta = _salahPengguna ? const Color(0xFFDC2626) : const Color(0xFF1E40AF);
    final ikon = _salahPengguna ? Icons.error_outline_rounded : Icons.info_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 18, color: tinta),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pesan,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: tinta,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
