import 'package:flutter/foundation.dart';

import '../enums.dart';

/// Penawaran harga dari seorang runner untuk order Jalur B.
///
/// Beberapa penawaran boleh menunggu jawaban klien secara bersamaan untuk
/// order yang sama, satu per runner yang berminat, mirip tawar-menawar di
/// aplikasi ojek daring. Penawaran adalah usulan, bukan keputusan. Selama
/// statusnya [OfferStatus.pending], angka di dalamnya belum boleh dianggap
/// harga order: harga baru pindah ke ordernya ketika klien menyetujui salah
/// satu penawaran, dan penawaran-penawaran lain otomatis [OfferStatus.ditutup].
/// Aturan itu ditegakkan di repository, bukan di layar.
@immutable
class OrderOffer {
  const OrderOffer({
    required this.id,
    required this.orderId,
    required this.runnerId,
    required this.namaRunner,
    this.noHpRunner,
    required this.harga,
    required this.estimasiDurasi,
    required this.jadwalMulai,
    required this.dibuatPada,
    required this.status,
    this.catatan,
  });

  final String id;
  final String orderId;

  /// Runner yang mengajukan penawaran ini.
  final String runnerId;

  /// Nama runner itu, supaya klien tahu siapa yang ia pilih sebelum
  /// menyetujui, bukan cuma harga dan jadwalnya.
  final String namaRunner;
  final String? noHpRunner;

  final int harga;
  final Duration estimasiDurasi;

  /// Kapan pekerjaannya dimulai menurut runner ini.
  ///
  /// Bisa berbeda dari waktu yang diminta klien, misalnya karena runner ini
  /// sedang ada urusan di jam itu. Perbedaannya bukan kesalahan, tapi harus
  /// terbaca jelas di layar sebelum klien menyetujui.
  final DateTime jadwalMulai;
  final DateTime dibuatPada;
  final OfferStatus status;
  final String? catatan;

  OrderOffer copyWith({OfferStatus? status}) {
    return OrderOffer(
      id: id,
      orderId: orderId,
      runnerId: runnerId,
      namaRunner: namaRunner,
      noHpRunner: noHpRunner,
      harga: harga,
      estimasiDurasi: estimasiDurasi,
      jadwalMulai: jadwalMulai,
      dibuatPada: dibuatPada,
      status: status ?? this.status,
      catatan: catatan,
    );
  }
}
