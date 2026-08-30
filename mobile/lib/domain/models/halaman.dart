import 'package:flutter/foundation.dart';

/// Sepotong daftar, beserta berapa banyak seluruhnya.
///
/// Yang penting di sini bukan [isi] melainkan [total]. Tanpa angka itu, layar tidak
/// bisa membedakan "ini memang semuanya" dari "ini baru sebagian", dan daftar yang
/// menampilkan dua puluh order padahal ada enam puluh tidak terlihat seperti bug;
/// ia terlihat seperti riwayat yang memang segitu.
///
/// Aplikasi ini tidak menumpuk halaman satu per satu. Ia meminta "yang terbaru
/// sebanyak N", dan tombol muat lagi memperbesar N. Alasannya bentuk streamnya:
/// daftar diambil ulang setiap lima belas detik, dan halaman yang ditumpuk sendiri
/// akan tertimpa setiap kali pengambilan ulang itu datang. Meminta jendela yang
/// lebih lebar membuat setiap pengambilan tetap menghasilkan satu potret yang utuh
/// dan konsisten.
@immutable
class Halaman<T> {
  const Halaman({required this.isi, required this.total});

  const Halaman.kosong() : isi = const [], total = 0;

  final List<T> isi;

  /// Seluruh baris yang cocok di server, bukan cuma yang terkirim.
  final int total;

  /// Benar kalau masih ada baris yang belum terbawa.
  bool get adaSisa => isi.length < total;

  Halaman<T> salinDengan({List<T>? isi}) =>
      Halaman<T>(isi: isi ?? this.isi, total: total);
}
