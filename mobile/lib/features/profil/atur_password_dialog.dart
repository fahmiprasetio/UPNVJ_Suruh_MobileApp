import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/tindakan_terkelola.dart';
import '../../core/config/batas_masukan.dart';
import '../../core/format/validasi_kontak.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/app_user.dart';
import '../../providers/repository_providers.dart';

/// Dua langkah: kirim kode OTP ke nomor sendiri, lalu password baru.
///
/// Bentuknya meniru [GantiNomorHpDialog] -- kode dulu, baru isian yang
/// dilindunginya -- untuk alasan yang sama: sesi yang sedang berjalan saja
/// tidak cukup untuk mengubah sesuatu yang bertahan lebih lama dari sesi itu
/// sendiri. Bedanya kodenya dikirim ke nomor sendiri lewat `mintaKode` biasa,
/// bukan endpoint terpisah seperti ganti nomor -- nomor tujuannya sudah pasti
/// nomor akun yang sedang masuk, jadi tidak ada yang perlu diminta selain
/// "kirim kode".
///
/// Mengembalikan [AppUser] yang baru kalau berhasil, atau `null` kalau
/// dibatalkan di langkah mana pun.
class AturPasswordDialog extends ConsumerStatefulWidget {
  const AturPasswordDialog({super.key, required this.noHp, required this.sudahPunyaPassword});

  final String noHp;
  final bool sudahPunyaPassword;

  @override
  ConsumerState<AturPasswordDialog> createState() => _AturPasswordDialogState();
}

enum _Langkah { mulai, isi }

class _AturPasswordDialogState extends ConsumerState<AturPasswordDialog>
    with TindakanTerkelola<AturPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _kodeController = TextEditingController();
  final _passwordController = TextEditingController();

  _Langkah _langkah = _Langkah.mulai;

  @override
  void dispose() {
    _kodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _kirimKode() => jalankan(_formKey, () async {
    await ref.read(authRepositoryProvider).mintaKode(noHp: widget.noHp);
    if (mounted) setState(() => _langkah = _Langkah.isi);
  });

  Future<void> _simpan() => jalankan(_formKey, () async {
    final user = await ref
        .read(authRepositoryProvider)
        .aturPassword(
          kode: _kodeController.text.trim(),
          password: _passwordController.text,
        );
    if (mounted) Navigator.of(context).pop(user);
  });

  String? _validasiPassword(String? nilai) {
    final isi = nilai ?? '';
    if (isi.length < BatasMasukan.passwordMinimal) {
      return 'Minimal ${BatasMasukan.passwordMinimal} karakter';
    }
    if (isi.length > BatasMasukan.password) {
      return 'Maksimal ${BatasMasukan.password} karakter';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.sudahPunyaPassword ? 'Ganti password' : 'Atur password'),
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
        FilledButton(
          onPressed: sedangMengirim ? null : (_langkah == _Langkah.mulai ? _kirimKode : _simpan),
          child: sedangMengirim
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_langkah == _Langkah.mulai ? 'Kirim kode' : 'Simpan'),
        ),
      ],
    );
  }

  String get _penjelasan => switch (_langkah) {
    _Langkah.mulai =>
      'Kami kirim kode sekali pakai ke ${widget.noHp}, untuk memastikan '
          'ini benar kamu sebelum ${widget.sudahPunyaPassword ? "menggantikan" : "menyimpan"} password.',
    _Langkah.isi => 'Masukkan kode yang dikirim, lalu password barumu.',
  };

  List<Widget> get _isiLangkah => switch (_langkah) {
    _Langkah.mulai => const [],
    _Langkah.isi => [
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
      const SizedBox(height: AppTheme.spasiSedang),
      TextFormField(
        controller: _passwordController,
        obscureText: true,
        enabled: !sedangMengirim,
        maxLength: BatasMasukan.password,
        decoration: const InputDecoration(labelText: 'Password baru'),
        validator: _validasiPassword,
      ),
    ],
  };
}
