import 'package:flutter/foundation.dart';

import '../enums.dart';

/// Catatan pembayaran satu order lewat payment gateway (mode sandbox,
/// bagian 6).
@immutable
class Payment {
  const Payment({
    required this.id,
    required this.orderId,
    required this.jumlah,
    required this.status,
    required this.dibuatPada,
    this.dibayarPada,
    this.referensiGateway,
  });

  final String id;
  final String orderId;
  final int jumlah;
  final PaymentStatus status;
  final DateTime dibuatPada;
  final DateTime? dibayarPada;
  final String? referensiGateway;
}
