import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/galat_api.dart';
import '../../core/api/tindakan_terkelola.dart';
import '../../core/format/validasi_kontak.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_theme.dart';

/// Menghapus akun sendiri, dalam tiga langkah: periksa, kirim kode, lalu hapus.
///
/// Bentuknya meniru [AturPasswordDialog] (kode dulu, baru tindakan yang dilindunginya),
/// dengan satu langkah tambahan di depan. Langkah periksa menanyakan ke server apakah
/// akunnya boleh dihapus SEBELUM kode diminta: orang yang masih punya pesanan berjalan
/// atau pengembalian dana yang belum selesai harus tahu itu sebelum menunggu SMS, bukan
/// setelah kodenya terpakai. Server tetap memeriksa ulang di langkah terakhir, karena
/// keadaannya bisa berubah di antara keduanya.
///
/// Persetujuan eksplisit lewat kotak centang, bukan cuma tombol: penghapusan tidak bisa
/// ditarik, dan tombol yang berwarna merah saja mudah tertekan tanpa dibaca.
///
/// Mengembalikan `true` kalau akunnya terhapus, atau `null` kalau dibatalkan di langkah
/// mana pun. Tidak ada navigasi sesudahnya: yang memindahkan layar adalah berakhirnya
/// sesi, dan itu diurus router (sama seperti saat keluar).
class HapusAkunDialog extends ConsumerStatefulWidget {
  const HapusAkunDialog({super.key, required this.noHp});

  final String noHp;

  @override
  ConsumerState<HapusAkunDialog> createState() => _HapusAkunDialogState();
}

enum _Langkah { memeriksa, ditolak, gagalMemeriksa, mulai, isi }

class _HapusAkunDialogState extends ConsumerState<HapusAkunDialog>
    with TindakanTerkelola<HapusAkunDialog> {
  final _formKey = GlobalKey<FormState>();
  final _kodeController = TextEditingController();

  _Langkah _langkah = _Langkah.memeriksa;
  List<String> _penghalang = const [];
  String? _galatPemeriksaan;
  bool _paham = false;

  @override
  void initState() {
    super.initState();
    _periksa();
  }

  @override
  void dispose() {
    _kodeController.dispose();
    super.dispose();
  }

  Future<void> _periksa() async {
    setState(() {
      _langkah = _Langkah.memeriksa;
      _galatPemeriksaan = null;
    });

    try {
      final penghalang = await ref
          .read(authRepositoryProvider)
          .penghalangPenghapusanAkun();
      if (!mounted) return;
      setState(() {
        _penghalang = penghalang;
        _langkah = penghalang.isEmpty ? _Langkah.mulai : _Langkah.ditolak;
      });
    } on GalatApi catch (galat) {
      _gagalMemeriksa(galat.pesan);
    } on StateError catch (galat) {
      _gagalMemeriksa(galat.message);
    }
  }

  void _gagalMemeriksa(String pesan) {
    if (!mounted) return;
    setState(() {
      _galatPemeriksaan = pesan;
      _langkah = _Langkah.gagalMemeriksa;
    });
  }

  Future<void> _kirimKode() => jalankan(_formKey, () async {
    await ref.read(authRepositoryProvider).mintaKode(noHp: widget.noHp);
    if (mounted) setState(() => _langkah = _Langkah.isi);
  });

  Future<void> _hapus() => jalankan(_formKey, () async {
    final pesan = ScaffoldMessenger.of(context);
    await ref
        .read(authRepositoryProvider)
        .hapusAkun(kode: _kodeController.text.trim());

    // Sesinya sudah berakhir di titik ini dan router sudah memindahkan layar;
    // pesannya dipasang lewat pengelola pesan yang diambil SEBELUM menunggu, karena
    // konteks dialog ini sebentar lagi tidak lagi berarti apa-apa.
    pesan
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Akunmu sudah dihapus.')));
    if (mounted) Navigator.of(context).pop(true);
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hapus akun'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._isi,
              if (galatTindakan != null) ...[
                const SizedBox(height: AppTheme.spasiSedang),
                Text(
                  galatTindakan!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: _aksi,
    );
  }

  List<Widget> get _isi => switch (_langkah) {
    _Langkah.memeriksa => const [
      Row(
        children: [
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppTheme.spasiSedang),
          Expanded(child: Text('Memeriksa akunmu...')),
        ],
      ),
    ],
    _Langkah.gagalMemeriksa => [Text(_galatPemeriksaan ?? 'Gagal memeriksa akunmu.')],
    _Langkah.ditolak => [
      const Text('Akunmu belum bisa dihapus saat ini:'),
      const SizedBox(height: AppTheme.spasiKecil),
      for (final alasan in _penghalang)
        Padding(
          padding: const EdgeInsets.only(top: AppTheme.spasiKecil),
          child: Text('• $alasan'),
        ),
    ],
    _Langkah.mulai => [
      const Text(
        'Akun dan data pribadimu akan dihapus dan tidak bisa dikembalikan: nama, '
        'nomor HP, alamat, password, serta isi pesan yang kamu kirim.\n\n'
        'Catatan transaksi (pesanan, pembayaran, riwayat status) tetap disimpan '
        'tanpa terhubung ke identitasmu. Penjelasan lengkapnya ada di Kebijakan '
        'Privasi.',
      ),
      const SizedBox(height: AppTheme.spasiSedang),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _paham,
        onChanged: sedangMengirim
            ? null
            : (nilai) => setState(() => _paham = nilai ?? false),
        title: const Text('Saya paham dan ingin menghapus akun ini.'),
      ),
      const SizedBox(height: AppTheme.spasiKecil),
      Text(
        'Kami kirim kode sekali pakai ke ${widget.noHp} untuk memastikan ini benar '
        'kamu.',
      ),
    ],
    _Langkah.isi => [
      const Text('Masukkan kode yang dikirim ke nomormu.'),
      const SizedBox(height: AppTheme.spasiSedang),
      TextFormField(
        controller: _kodeController,
        keyboardType: TextInputType.number,
        autofocus: true,
        enabled: !sedangMengirim,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 8,
        ),
        decoration: const InputDecoration(
          labelText: 'Kode',
          floatingLabelAlignment: FloatingLabelAlignment.center,
          counterText: '',
        ),
        validator: validasiKode,
      ),
    ],
  };

  List<Widget> get _aksi {
    final galat = Theme.of(context).colorScheme.error;
    const spinner = SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

    return switch (_langkah) {
      _Langkah.memeriksa => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
      _Langkah.ditolak => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
      _Langkah.gagalMemeriksa => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        FilledButton(onPressed: _periksa, child: const Text('Coba lagi')),
      ],
      _Langkah.mulai => [
        TextButton(
          onPressed: sedangMengirim ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: (sedangMengirim || !_paham) ? null : _kirimKode,
          child: sedangMengirim ? spinner : const Text('Kirim kode'),
        ),
      ],
      _Langkah.isi => [
        TextButton(
          onPressed: sedangMengirim ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: galat),
          onPressed: sedangMengirim ? null : _hapus,
          child: sedangMengirim ? spinner : const Text('Hapus akun'),
        ),
      ],
    };
  }
}
