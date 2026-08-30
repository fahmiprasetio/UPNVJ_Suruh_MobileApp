import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/batas_halaman.dart';

/// Berapa banyak baris yang sedang diminta sebuah daftar.
///
/// Aplikasi ini tidak menumpuk halaman satu per satu. Ia meminta "yang terbaru
/// sebanyak N", dan [perbesar] menaikkan N. Alasannya bentuk aliran datanya: daftar
/// diambil ulang setiap lima belas detik, dan halaman yang ditumpuk di sisi aplikasi
/// akan tertimpa setiap kali pengambilan ulang itu datang. Meminta jendela yang lebih
/// lebar membuat setiap pengambilan tetap menghasilkan satu potret yang utuh dan
/// konsisten, tanpa ada keadaan yang harus dijahit sendiri.
///
/// Disimpan di provider, bukan di dalam State layar, supaya jendelanya tidak menciut
/// kembali setiap kali layarnya dibangun ulang. Layar yang mengembalikan jendelanya ke
/// dua puluh setiap kali daftar berubah akan menghapus hasil "muat lagi" yang baru saja
/// ditekan orang.
///
/// Berhenti di [BatasHalaman.maksimal] karena server menolak permintaan yang lebih
/// besar. Riwayat yang melewati angka itu menuntut penumpukan halaman yang sesungguhnya,
/// dan itu perubahan yang lebih besar daripada menaikkan satu konstanta.
class UkuranDaftar extends Notifier<int> {
  @override
  int build() => BatasHalaman.bawaan;

  /// Benar selama masih ada ruang untuk memperlebar jendelanya.
  bool get bisaDiperbesar => state < BatasHalaman.maksimal;

  void perbesar() {
    if (!bisaDiperbesar) return;
    state = (state + BatasHalaman.tambahan).clamp(0, BatasHalaman.maksimal);
  }
}

/// Jendela daftar order klien.
final ukuranOrderKlienProvider = NotifierProvider<UkuranDaftar, int>(
  UkuranDaftar.new,
);

/// Jendela daftar order yang dipegang runner.
final ukuranOrderRunnerProvider = NotifierProvider<UkuranDaftar, int>(
  UkuranDaftar.new,
);

/// Jendela daftar siaran.
///
/// Punya jendelanya sendiri walaupun isinya tidak menumpuk seperti dua di atas:
/// siaran cuma memuat order yang sedang mencari runner, jadi ia menyusut sendiri
/// begitu ada yang mengambilnya. Dibuat seragam supaya tidak ada satu daftar yang
/// diam-diam tidak berbatas, yaitu justru yang paling mudah terlewat.
final ukuranOrderTersiarProvider = NotifierProvider<UkuranDaftar, int>(
  UkuranDaftar.new,
);
