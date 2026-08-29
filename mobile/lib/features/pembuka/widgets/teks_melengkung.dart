import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tulisan yang mengikuti busur lingkaran, muncul huruf demi huruf.
///
/// Dipakai untuk "UPNVJ SURUH" di bawah lencana. Tulisannya digambar, bukan
/// disimpan sebagai gambar, karena yang diinginkan adalah hurufnya muncul satu
/// per satu dari kiri ke kanan. Sebagai gambar, satu-satunya animasi yang mungkin
/// adalah menyingkap seluruh baris di balik topeng, dan itu terlihat sebagai
/// tirai, bukan sebagai huruf yang berdatangan.
///
/// Pusat busurnya adalah pusat kotak yang diberikan padanya, jadi widget ini
/// harus diberi kotak yang sepusat dengan lencananya.
class TeksMelengkung extends StatelessWidget {
  const TeksMelengkung({
    super.key,
    required this.teks,
    required this.jariJari,
    required this.gaya,
    required this.kemajuan,
  });

  final String teks;

  /// Jarak garis alas huruf dari pusat busur, dalam piksel.
  final double jariJari;

  final TextStyle gaya;

  /// 0 berarti belum ada huruf yang muncul, 1 berarti semuanya sudah di tempat.
  final double kemajuan;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: teks,
      child: CustomPaint(
        painter: _PelukisTeksMelengkung(
          teks: teks,
          jariJari: jariJari,
          gaya: gaya,
          kemajuan: kemajuan,
        ),
      ),
    );
  }
}

class _PelukisTeksMelengkung extends CustomPainter {
  _PelukisTeksMelengkung({
    required this.teks,
    required this.jariJari,
    required this.gaya,
    required this.kemajuan,
  });

  final String teks;
  final double jariJari;
  final TextStyle gaya;
  final double kemajuan;

  /// Lebar jendela kemunculan satu huruf, dalam satuan [kemajuan].
  ///
  /// Nilainya lebih besar dari jarak antar huruf, jadi jendelanya saling
  /// bertumpuk: huruf berikutnya sudah mulai muncul sebelum huruf sebelumnya
  /// selesai. Tanpa tumpukan itu, hurufnya terbaca sebagai sebelas kejadian
  /// terpisah, bukan satu tulisan yang sedang tertulis.
  static const double _jendelaHuruf = 0.34;

  @override
  void paint(Canvas canvas, Size size) {
    if (kemajuan <= 0 || teks.isEmpty) return;

    final pusat = Offset(size.width / 2, size.height / 2);
    final huruf = teks.characters.toList();

    // Lebar tiap huruf diukur lebih dulu, karena posisi sudut huruf pertama
    // baru bisa dihitung setelah lebar seluruh tulisan diketahui.
    final lebar = <double>[];
    var totalSudut = 0.0;
    for (final h in huruf) {
      final w = _ukurLebar(h);
      lebar.add(w);
      totalSudut += w / jariJari;
    }

    // Titik terkiri busur adalah sudut terbesar: pada kanvas Flutter sumbu y
    // menghadap ke bawah, jadi sudut yang membesar dari 90 derajat bergerak ke
    // kiri sepanjang setengah lingkaran bawah.
    var sudut = math.pi / 2 + totalSudut / 2;
    final jarakMulai = _jarakMulai(huruf.length);

    for (var i = 0; i < huruf.length; i++) {
      final lebarSudut = lebar[i] / jariJari;
      sudut -= lebarSudut / 2;

      final t = ((kemajuan - i * jarakMulai) / _jendelaHuruf).clamp(0.0, 1.0);
      if (t > 0) {
        _gambarHuruf(canvas, pusat, huruf[i], sudut, t);
      }

      sudut -= lebarSudut / 2;
    }
  }

  /// Jarak antar awal kemunculan dua huruf berurutan.
  ///
  /// Huruf terakhir harus selesai tepat saat [kemajuan] mencapai 1, jadi huruf
  /// terakhir dimulai di `1 - _jendelaHuruf` dan sisanya dibagi rata.
  double _jarakMulai(int jumlah) =>
      jumlah <= 1 ? 0 : (1 - _jendelaHuruf) / (jumlah - 1);

  double _ukurLebar(String huruf) {
    // Spasi diukur sendiri karena TextPainter memangkas spasi di ujung baris,
    // sehingga jaraknya menjadi nol dan "UPNVJ SURUH" terbaca menyatu.
    if (huruf.trim().isEmpty) return (gaya.fontSize ?? 14) * 0.28;
    return (_pelukisHuruf(huruf, gaya)..layout()).width;
  }

  void _gambarHuruf(
    Canvas canvas,
    Offset pusat,
    String huruf,
    double sudut,
    double t,
  ) {
    if (huruf.trim().isEmpty) return;

    final muncul = Curves.easeOut.transform(t);
    final mendarat = Curves.easeOutBack.transform(t);

    final pelukis = _pelukisHuruf(
      huruf,
      gaya.copyWith(
        color: (gaya.color ?? const Color(0xFF000000)).withValues(
          alpha: muncul,
        ),
      ),
    )..layout();

    // Garis alas huruf, bukan tepi bawah kotaknya. Kalau yang dipakai tinggi
    // kotak, ruang untuk ekor huruf ikut terhitung, dan seluruh tulisan
    // terangkat menjauhi busur padahal di logo aslinya ia menempel.
    final alas = pelukis.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );

    canvas.save();
    canvas.translate(
      pusat.dx + jariJari * math.cos(sudut),
      pusat.dy + jariJari * math.sin(sudut),
    );
    // Huruf berdiri tegak lurus busur, kepalanya menghadap pusat lingkaran.
    canvas.rotate(sudut - math.pi / 2);
    // Sumbu y positif di kerangka ini menjauhi pusat, jadi huruf yang belum
    // selesai muncul berada di luar lingkaran dan bergerak masuk ke tempatnya.
    canvas.translate(0, (1 - mendarat) * (gaya.fontSize ?? 14) * 0.5);
    pelukis.paint(canvas, Offset(-pelukis.width / 2, -alas));
    canvas.restore();
  }

  TextPainter _pelukisHuruf(String huruf, TextStyle gaya) => TextPainter(
    text: TextSpan(text: huruf, style: gaya),
    textDirection: TextDirection.ltr,
  );

  @override
  bool shouldRepaint(_PelukisTeksMelengkung lama) =>
      lama.kemajuan != kemajuan ||
      lama.teks != teks ||
      lama.jariJari != jariJari ||
      lama.gaya != gaya;
}
