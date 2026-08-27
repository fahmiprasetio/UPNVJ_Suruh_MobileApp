import 'package:flutter/foundation.dart';

import '../enums.dart';

/// Penawaran harga dari admin untuk order Jalur B (bagian 3).
///
/// Penawaran adalah usulan, bukan keputusan. Selama statusnya
/// [OfferStatus.pending], angka di dalamnya belum boleh dianggap harga order:
/// harga baru pindah ke ordernya ketika klien menekan setuju. Aturan itu
/// ditegakkan di repository, bukan di layar.
@immutable
class OrderOffer {
  const OrderOffer({
    required this.id,
    required this.orderId,
    required this.harga,
    required this.estimasiDurasi,
    required this.jadwalMulai,
    required this.dibuatPada,
    required this.status,
    this.catatan,
  });

  final String id;
  final String orderId;
  final int harga;
  final Duration estimasiDurasi;

  /// Kapan pekerjaannya dimulai menurut admin.
  ///
  /// Bisa berbeda dari waktu yang diminta klien, misalnya karena tim sedang
  /// penuh di jam itu. Perbedaannya bukan kesalahan, tapi harus terbaca jelas
  /// di layar sebelum klien menyetujui.
  final DateTime jadwalMulai;
  final DateTime dibuatPada;
  final OfferStatus status;
  final String? catatan;

  OrderOffer copyWith({OfferStatus? status}) {
    return OrderOffer(
      id: id,
      orderId: orderId,
      harga: harga,
      estimasiDurasi: estimasiDurasi,
      jadwalMulai: jadwalMulai,
      dibuatPada: dibuatPada,
      status: status ?? this.status,
      catatan: catatan,
    );
  }
}
