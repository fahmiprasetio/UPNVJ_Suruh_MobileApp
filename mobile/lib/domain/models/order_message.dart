import 'package:flutter/foundation.dart';

import '../enums.dart';

/// Pesan di dalam ruang chat sebuah order.
///
/// Chat tidak pernah berdiri sendiri — selalu menempel pada satu order
/// (bagian 4, "Prinsip inti").
@immutable
class OrderMessage {
  const OrderMessage({
    required this.id,
    required this.orderId,
    required this.pengirim,
    required this.isi,
    required this.dikirimPada,
    this.fotoUrl,
  });

  final String id;
  final String orderId;
  final MessageSender pengirim;
  final String isi;
  final DateTime dikirimPada;
  final String? fotoUrl;
}
