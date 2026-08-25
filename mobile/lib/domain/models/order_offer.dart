import 'package:flutter/foundation.dart';

import '../enums.dart';

/// Penawaran harga dari admin untuk order Jalur B (bagian 3).
@immutable
class OrderOffer {
  const OrderOffer({
    required this.id,
    required this.orderId,
    required this.harga,
    required this.estimasiDurasi,
    required this.dibuatPada,
    required this.status,
    this.catatan,
  });

  final String id;
  final String orderId;
  final int harga;
  final Duration estimasiDurasi;
  final DateTime dibuatPada;
  final OfferStatus status;
  final String? catatan;

  OrderOffer copyWith({OfferStatus? status}) {
    return OrderOffer(
      id: id,
      orderId: orderId,
      harga: harga,
      estimasiDurasi: estimasiDurasi,
      dibuatPada: dibuatPada,
      status: status ?? this.status,
      catatan: catatan,
    );
  }
}
