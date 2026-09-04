import 'package:flutter/foundation.dart';

import '../enums.dart';
import 'halaman.dart';

/// Satu order yang pernah dikerjakan runner, beserta bayarannya.
@immutable
class BarisPendapatan {
  const BarisPendapatan({
    required this.penugasanId,
    required this.orderId,
    required this.kodeOrder,
    required this.layanan,
    required this.selesaiPada,
    required this.jumlah,
    required this.dibayarPada,
  });

  final String penugasanId;
  final String orderId;
  final String kodeOrder;
  final ServiceType layanan;
  final DateTime? selesaiPada;

  /// Bayaran untuk order ini, dan `null` kalau belum bisa dihitung.
  ///
  /// Null bukan nol. Order yang selesai selagi admin belum menyimpan rumus bagi
  /// hasil menunggu di keadaan ini sampai rumus itu ada; menggambarnya sebagai
  /// Rp 0 berarti runner membaca bahwa pekerjaannya memang tidak dibayar.
  final int? jumlah;

  /// Kapan uangnya diserahkan organisasi, dan `null` selama belum.
  final DateTime? dibayarPada;

  bool get sudahDibayar => dibayarPada != null;
  bool get menungguRumus => jumlah == null;
}

/// Pendapatan seorang runner: yang masih ditunggu, yang sudah diterima, dan dari
/// order mana saja.
@immutable
class Pendapatan {
  const Pendapatan({
    required this.totalBelumDibayar,
    required this.totalSudahDibayar,
    required this.menungguRumus,
    required this.rincian,
  });

  /// Keduanya dihitung server atas seluruh riwayat, bukan atas halaman yang
  /// sedang tampil. "Berapa yang belum saya terima" cuma punya satu jawaban
  /// benar, dan jawaban yang menjumlahkan dua puluh baris teratas salah tanpa
  /// terlihat salah.
  final int totalBelumDibayar;
  final int totalSudahDibayar;

  /// Banyak order selesai yang bayarannya belum bisa dihitung karena admin belum
  /// menyimpan rumus bagi hasil.
  ///
  /// Ditampilkan apa adanya, bukan disembunyikan: runner yang menyelesaikan lima
  /// order lalu melihat pendapatan nol berhak tahu bahwa ordernya tercatat dan
  /// yang belum ada adalah angkanya, bukan pekerjaannya.
  final int menungguRumus;

  final Halaman<BarisPendapatan> rincian;

  /// Belum ada apa pun yang bisa ditampilkan.
  bool get kosong => rincian.isi.isEmpty;
}
