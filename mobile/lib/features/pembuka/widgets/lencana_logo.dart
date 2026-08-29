import 'package:flutter/material.dart';

/// Ukuran-ukuran yang diambil dari gambar lencananya sendiri.
///
/// Teks "UPNVJ SURUH" digambar dari kode, sementara cincin yang harus dipeluknya
/// ikut tercetak di dalam `lencana.png`. Supaya keduanya sepusat, kode perlu tahu
/// di mana cincin itu berada di dalam berkasnya. Angka-angka di bawah bukan
/// kira-kira: berkasnya sengaja dibuat ulang dari `assets/tanpa nama.png` dengan
/// latar putih dibuang dan kanvas digeser sampai pusat cincin jatuh persis di
/// tengah gambar, lalu jari-jarinya diukur dari sana.
///
/// Kalau `lencana.png` diganti, angka-angka ini harus diukur ulang, dan itu
/// sebabnya semuanya ditulis di satu tempat.
class GeometriLencana {
  const GeometriLencana._();

  /// Jari-jari cincin, sebagai pecahan dari sisi gambar yang berbentuk bujur
  /// sangkar. Pusat cincin berimpit dengan pusat gambar.
  static const double jariJariCincin = 0.478;

  /// Jarak garis alas teks dari pusat cincin, sebagai kelipatan
  /// [jariJariCincin].
  ///
  /// Di logo aslinya nilai ini 1,25: alas huruf di titik terbawah berada 464
  /// piksel dari pusat, cincinnya 371 piksel. Dipakai lebih jauh di sini karena
  /// logo aslinya adalah gambar diam yang dipandang utuh, sementara ini layar
  /// yang dilewati: tulisan yang menempel di cincin membuat keduanya terbaca
  /// sebagai satu gumpalan gelap di detik yang cuma sekejap itu. Menjauhkannya
  /// juga mengecilkan rentang sudutnya, karena busur yang lebih besar memuat
  /// lebar yang sama dalam sudut yang lebih kecil.
  static const double jariJariAlasTeks = 1.46;

  /// Tinggi huruf, sebagai kelipatan [jariJariCincin].
  ///
  /// Di logo aslinya nilai ini 0,372. Dikecilkan karena tulisannya di sini
  /// bukan bagian yang harus dibaca, cuma yang harus dikenali: yang membawa
  /// nama justru lencananya.
  static const double ukuranHuruf = 0.29;

  /// Sisi kotak yang memuat lencana beserta tulisan melengkungnya, sebagai
  /// kelipatan sisi lencana. Tulisan jatuh di luar lingkaran lencana, jadi
  /// kotaknya harus lebih besar dari lencananya sendiri atau hurufnya terpotong.
  static const double kotakKomposisi = 1.66;

  /// Hijau kehitaman yang dipakai garis luar dan tulisan di logo aslinya.
  static const Color warnaTinta = Color(0xFF1E302E);
}

/// Gambar lencana: buaya berhelm mengendarai motor, di dalam cincin, di atas
/// jalan tanah. Tanpa tulisan, karena tulisannya dianimasikan dari kode.
class LencanaLogo extends StatelessWidget {
  const LencanaLogo({super.key, required this.sisi});

  final double sisi;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/lencana.png',
      width: sisi,
      height: sisi,
      fit: BoxFit.contain,
      // Lencananya penuh garis tipis dan lengkungan halus. Dengan penyaringan
      // bawaan, garis-garis itu bergerigi begitu gambar diperkecil dari 512 px
      // ke ukuran tampil yang biasanya sekitar 260 px.
      filterQuality: FilterQuality.medium,
    );
  }
}
