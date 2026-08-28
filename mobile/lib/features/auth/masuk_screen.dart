import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/galat_api.dart';
import '../../core/config/batas_masukan.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/repository_providers.dart';

/// Langkah yang sedang ditampilkan.
///
/// Ketiganya tinggal di satu layar, bukan tiga rute, karena semuanya memakai
/// nomor HP yang sama. Memecahnya jadi beberapa rute berarti nomor itu harus
/// dioper lewat jalur atau disimpan di suatu tempat di luar layar, dan keduanya
/// menambah bagian yang bisa salah demi perpindahan yang tidak diminta siapa pun.
enum _Langkah { nomor, daftar, kode }

/// Layar masuk: nomor HP, lalu kode sekali pakai yang dikirim ke nomor itu.
class MasukScreen extends ConsumerStatefulWidget {
  const MasukScreen({super.key});

  @override
  ConsumerState<MasukScreen> createState() => _MasukScreenState();
}

class _MasukScreenState extends ConsumerState<MasukScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _noHpController = TextEditingController();
  final _kodeController = TextEditingController();

  _Langkah _langkah = _Langkah.nomor;
  bool _sedangMengirim = false;
  String? _galat;

  @override
  void dispose() {
    _namaController.dispose();
    _noHpController.dispose();
    _kodeController.dispose();
    super.dispose();
  }

  String? _validasiNoHp(String? nilai) {
    final bersih = (nilai ?? '').trim();
    if (bersih.isEmpty) return 'Nomor HP belum diisi';
    // Pola yang sama dengan yang dipakai server. Kalau berbeda, akan ada nomor
    // yang lolos di sini lalu ditolak di sana, dan pengguna melihat penolakan
    // tanpa tahu bagian mana yang salah.
    if (!RegExp(r'^08\d{8,13}$').hasMatch(bersih)) {
      return 'Nomor HP diawali 08 dan berisi 10 sampai 15 angka';
    }
    return null;
  }

  String? _validasiNama(String? nilai) {
    final bersih = (nilai ?? '').trim();
    if (bersih.isEmpty) return 'Nama belum diisi';
    if (bersih.length > BatasMasukan.nama) {
      return 'Nama maksimal ${BatasMasukan.nama} karakter';
    }
    return null;
  }

  String? _validasiKode(String? nilai) {
    final bersih = (nilai ?? '').trim();
    if (bersih.isEmpty) return 'Kode belum diisi';
    if (!RegExp(r'^\d{6}$').hasMatch(bersih)) return 'Kode terdiri dari 6 angka';
    return null;
  }

  /// Menjalankan satu tindakan yang bicara ke server, sambil menjaga layar tetap
  /// jujur soal keadaannya.
  ///
  /// Semua penanganan galat lewat sini supaya tidak ada satu pun jalur yang lupa
  /// mematikan keadaan memuat. Tombol yang tinggal berputar selamanya setelah
  /// permintaan gagal adalah kegagalan yang paling sering lolos ke pengguna.
  Future<void> _jalankan(Future<void> Function() tindakan) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sedangMengirim = true;
      _galat = null;
    });

    try {
      await tindakan();
    } on GalatApi catch (galat) {
      if (mounted) setState(() => _galat = galat.pesan);
    } on StateError catch (galat) {
      // Repository tiruan melempar StateError. Pesannya sudah ditulis untuk
      // dibaca orang, jadi dipakai apa adanya.
      if (mounted) setState(() => _galat = galat.message);
    } finally {
      if (mounted) setState(() => _sedangMengirim = false);
    }
  }

  Future<void> _kirimKode() => _jalankan(() async {
    await ref
        .read(authRepositoryProvider)
        .mintaKode(noHp: _noHpController.text.trim());
    if (mounted) setState(() => _langkah = _Langkah.kode);
  });

  Future<void> _daftarLaluKirimKode() => _jalankan(() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.daftar(
      nama: _namaController.text.trim(),
      noHp: _noHpController.text.trim(),
    );
    // Langsung dilanjutkan, bukan dikembalikan ke langkah nomor. Orang yang baru
    // saja mengetik nomornya tidak perlu mengetiknya lagi untuk minta kode.
    await repo.mintaKode(noHp: _noHpController.text.trim());
    if (mounted) setState(() => _langkah = _Langkah.kode);
  });

  Future<void> _masuk() => _jalankan(() async {
    await ref
        .read(authRepositoryProvider)
        .masuk(
          noHp: _noHpController.text.trim(),
          kode: _kodeController.text.trim(),
        );
    // Tidak ada navigasi di sini. Yang memindahkan layar adalah berubahnya sesi,
    // dan itu diurus router. Layar yang mendorong dirinya sendiri setelah masuk
    // akan bertabrakan dengan pengalihan router dan menyisakan layar masuk di
    // tumpukan belakang.
  });

  void _kembaliKeNomor() {
    _kodeController.clear();
    setState(() {
      _langkah = _Langkah.nomor;
      _galat = null;
    });
  }

  void _keDaftar() {
    setState(() {
      _langkah = _Langkah.daftar;
      _galat = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spasiBesar),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('UPNVJ Suruh', style: teks.headlineSmall),
                    const SizedBox(height: AppTheme.spasiKecil),
                    Text(_penjelasan, style: teks.bodyMedium),
                    const SizedBox(height: AppTheme.spasiBesar),
                    ..._isiLangkah,
                    if (_galat != null) ...[
                      const SizedBox(height: AppTheme.spasiSedang),
                      _KotakGalat(pesan: _galat!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _penjelasan => switch (_langkah) {
    _Langkah.nomor => 'Masuk pakai nomor HP. Kami kirimkan kode sekali pakai.',
    _Langkah.daftar => 'Daftar dulu, sebentar saja.',
    _Langkah.kode =>
      'Masukkan 6 angka yang dikirim ke ${_noHpController.text.trim()}.',
  };

  List<Widget> get _isiLangkah => switch (_langkah) {
    _Langkah.nomor => [
      _kolomNoHp(),
      const SizedBox(height: AppTheme.spasiSedang),
      _tombolUtama(label: 'Kirim kode', aksi: _kirimKode),
      const SizedBox(height: AppTheme.spasiKecil),
      TextButton(
        onPressed: _sedangMengirim ? null : _keDaftar,
        child: const Text('Belum punya akun? Daftar'),
      ),
    ],
    _Langkah.daftar => [
      TextFormField(
        controller: _namaController,
        maxLength: BatasMasukan.nama,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nama',
          hintText: 'Nama yang dipakai runner memanggilmu',
        ),
        validator: _validasiNama,
      ),
      _kolomNoHp(),
      const SizedBox(height: AppTheme.spasiSedang),
      _tombolUtama(label: 'Daftar', aksi: _daftarLaluKirimKode),
      const SizedBox(height: AppTheme.spasiKecil),
      TextButton(
        onPressed: _sedangMengirim ? null : _kembaliKeNomor,
        child: const Text('Sudah punya akun? Masuk'),
      ),
    ],
    _Langkah.kode => [
      TextFormField(
        controller: _kodeController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Kode', counterText: ''),
        validator: _validasiKode,
      ),
      const SizedBox(height: AppTheme.spasiSedang),
      _tombolUtama(label: 'Masuk', aksi: _masuk),
      const SizedBox(height: AppTheme.spasiKecil),
      TextButton(
        onPressed: _sedangMengirim ? null : _kembaliKeNomor,
        child: const Text('Ganti nomor'),
      ),
      const SizedBox(height: AppTheme.spasiKecil),
      // Meminta kode berakhir sama saja untuk nomor yang terdaftar maupun tidak,
      // supaya langkah itu tidak jadi alat memeriksa siapa saja yang punya akun.
      // Akibatnya orang yang belum punya akun baru tahu di sini, dan itu berarti
      // di sini pula ia harus diberi jalan keluar.
      Text(
        'Nomor yang belum terdaftar tidak menerima kode. Kalau kodenya tidak '
        'kunjung datang, mungkin akunmu memang belum ada.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      TextButton(
        onPressed: _sedangMengirim ? null : _keDaftar,
        child: const Text('Daftar akun baru'),
      ),
    ],
  };

  Widget _kolomNoHp() => TextFormField(
    controller: _noHpController,
    keyboardType: TextInputType.phone,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(BatasMasukan.nomorHp),
    ],
    decoration: const InputDecoration(
      labelText: 'Nomor HP',
      hintText: '08xxxxxxxxxx',
    ),
    validator: _validasiNoHp,
  );

  Widget _tombolUtama({
    required String label,
    required Future<void> Function() aksi,
  }) => FilledButton(
    onPressed: _sedangMengirim ? null : aksi,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    child: _sedangMengirim
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label),
  );
}

class _KotakGalat extends StatelessWidget {
  const _KotakGalat({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      decoration: BoxDecoration(
        color: skema.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: skema.onErrorContainer),
          const SizedBox(width: AppTheme.spasiKecil),
          Expanded(
            child: Text(
              pesan,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: skema.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
