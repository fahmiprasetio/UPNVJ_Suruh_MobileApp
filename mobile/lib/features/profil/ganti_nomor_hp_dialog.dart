import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/tindakan_terkelola.dart';
import '../../core/config/batas_masukan.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/app_user.dart';
import '../../providers/repository_providers.dart';

/// Dua langkah: nomor HP baru, lalu kode yang dikirim ke nomor itu.
///
/// ## Kenapa dialog, bukan satu kolom di kartu sunting
///
/// Nama dan alamat di kartu sunting berubah lewat satu isian karena tidak ada
/// yang perlu dibuktikan selain "ini yang kamu mau" -- server percaya begitu
/// saja. Nomor HP beda: ia identitas masuk, dan mengubahnya lewat satu kolom
/// berarti siapa pun yang sempat memegang HP orang lain sebentar bisa
/// memindahkan akunnya ke nomornya sendiri. Yang harus dibuktikan lebih dulu
/// kepemilikan nomor barunya, dan pembuktian itu butuh jeda menunggu SMS --
/// sesuatu yang tidak muat di satu baris kartu yang sama dengan isian lain.
///
/// Dialog terpisah membuat jeda itu jelas: dua langkah, satu tujuan, dan
/// selesai atau batal begitu ditutup. Bentuknya sengaja meniru `MasukScreen`,
/// yang juga dua langkah nomor-lalu-kode untuk alasan yang sama persis.
///
/// Mengembalikan [AppUser] yang baru kalau berhasil, atau `null` kalau
/// dibatalkan di langkah mana pun.
class GantiNomorHpDialog extends ConsumerStatefulWidget {
  const GantiNomorHpDialog({super.key, required this.noHpSekarang});

  final String noHpSekarang;

  @override
  ConsumerState<GantiNomorHpDialog> createState() => _GantiNomorHpDialogState();
}

enum _Langkah { nomor, kode }

class _GantiNomorHpDialogState extends ConsumerState<GantiNomorHpDialog>
    with TindakanTerkelola<GantiNomorHpDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noHpController = TextEditingController();
  final _kodeController = TextEditingController();

  _Langkah _langkah = _Langkah.nomor;

  @override
  void dispose() {
    _noHpController.dispose();
    _kodeController.dispose();
    super.dispose();
  }

  String? _validasiNoHp(String? nilai) {
    final bersih = (nilai ?? '').trim();
    if (bersih.isEmpty) return 'Nomor HP belum diisi';
    // Pola yang sama dengan yang dipakai server (lihat MintaKodeGantiNomorRequest),
    // supaya tidak ada nomor yang lolos di sini lalu ditolak di sana.
    if (!RegExp(r'^08\d{8,13}$').hasMatch(bersih)) {
      return 'Nomor HP diawali 08 dan berisi 10 sampai 15 angka';
    }
    if (bersih == widget.noHpSekarang) {
      return 'Ini nomor yang sekarang, tidak ada yang perlu diganti';
    }
    return null;
  }

  String? _validasiKode(String? nilai) {
    final bersih = (nilai ?? '').trim();
    if (bersih.isEmpty) return 'Kode belum diisi';
    if (!RegExp(r'^\d{6}$').hasMatch(bersih)) {
      return 'Kode terdiri dari 6 angka';
    }
    return null;
  }

  Future<void> _kirimKode() => jalankan(_formKey, () async {
    await ref
        .read(authRepositoryProvider)
        .mintaKodeGantiNomor(noHpBaru: _noHpController.text.trim());
    if (mounted) setState(() => _langkah = _Langkah.kode);
  });

  Future<void> _konfirmasi() => jalankan(_formKey, () async {
    final user = await ref.read(authRepositoryProvider).konfirmasiGantiNomor(
      noHpBaru: _noHpController.text.trim(),
      kode: _kodeController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(user);
  });

  void _kembaliKeNomor() {
    _kodeController.clear();
    setState(() {
      _langkah = _Langkah.nomor;
      galatTindakan = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ganti nomor HP'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_penjelasan),
            const SizedBox(height: AppTheme.spasiSedang),
            ..._isiLangkah,
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
      actions: [
        TextButton(
          onPressed: sedangMengirim ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        if (_langkah == _Langkah.kode)
          TextButton(
            onPressed: sedangMengirim ? null : _kembaliKeNomor,
            child: const Text('Ganti nomor'),
          ),
        FilledButton(
          onPressed: sedangMengirim
              ? null
              : (_langkah == _Langkah.nomor ? _kirimKode : _konfirmasi),
          child: sedangMengirim
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_langkah == _Langkah.nomor ? 'Kirim kode' : 'Konfirmasi'),
        ),
      ],
    );
  }

  String get _penjelasan => switch (_langkah) {
    _Langkah.nomor =>
      'Kami kirim kode sekali pakai ke nomor barumu, untuk memastikan itu '
          'benar nomormu.',
    _Langkah.kode =>
      'Masukkan 6 angka yang dikirim ke ${_noHpController.text.trim()}.',
  };

  List<Widget> get _isiLangkah => switch (_langkah) {
    _Langkah.nomor => [
      TextFormField(
        controller: _noHpController,
        keyboardType: TextInputType.phone,
        autofocus: true,
        enabled: !sedangMengirim,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(BatasMasukan.nomorHp),
        ],
        decoration: const InputDecoration(
          labelText: 'Nomor HP baru',
          hintText: '08xxxxxxxxxx',
        ),
        validator: _validasiNoHp,
      ),
    ],
    _Langkah.kode => [
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
        validator: _validasiKode,
      ),
    ],
  };
}
