import 'package:flutter/widgets.dart';

import 'galat_api.dart';

/// Menjalankan satu tindakan yang bicara ke server, sambil menjaga layar tetap jujur
/// soal keadaannya: sedang mengirim atau tidak, dan kalimat galat terakhir kalau gagal.
///
/// Sebelum disatukan di sini, pola ini disalin identik di `MasukScreen` dan
/// `GantiNomorHpDialog` -- keduanya layar/dialog dua langkah yang validasi form-nya,
/// menjaga indikator memuat, dan menerjemahkan galat dengan cara yang sama persis.
mixin TindakanTerkelola<T extends StatefulWidget> on State<T> {
  bool sedangMengirim = false;
  String? galatTindakan;

  /// [formKey] divalidasi lebih dulu; kalau tidak lolos, [tindakan] tidak pernah
  /// dijalankan sama sekali.
  ///
  /// Semua penanganan galat lewat sini supaya tidak ada satu pun jalur yang lupa
  /// mematikan keadaan memuat. Tombol yang tinggal berputar selamanya setelah
  /// permintaan gagal adalah kegagalan yang paling sering lolos ke pengguna.
  Future<void> jalankan(
    GlobalKey<FormState> formKey,
    Future<void> Function() tindakan,
  ) async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      sedangMengirim = true;
      galatTindakan = null;
    });

    try {
      await tindakan();
    } on GalatApi catch (galat) {
      if (mounted) setState(() => galatTindakan = galat.pesan);
    } on StateError catch (galat) {
      // Repository tiruan melempar StateError. Pesannya sudah ditulis untuk dibaca
      // orang, jadi dipakai apa adanya.
      if (mounted) setState(() => galatTindakan = galat.message);
    } finally {
      if (mounted) setState(() => sedangMengirim = false);
    }
  }
}
