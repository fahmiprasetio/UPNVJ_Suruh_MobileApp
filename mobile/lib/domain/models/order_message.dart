import 'package:flutter/foundation.dart';

import '../enums.dart';

/// Pesan di dalam ruang chat sebuah order.
///
/// Chat tidak pernah berdiri sendiri, selalu menempel pada satu order
/// (bagian 4, "Prinsip inti").
@immutable
class OrderMessage {
  const OrderMessage({
    required this.id,
    required this.orderId,
    required this.pengirim,
    required this.isi,
    required this.dikirimPada,
    this.runnerId,
    this.fotoUrl,
  });

  final String id;
  final String orderId;

  /// Jalur obrolan pribadi milik runner ini pada tahap tawar-menawar Jalur B,
  /// atau `null` kalau pesan ini bukan bagian dari tawar-menawar (chat umum
  /// Jalur A, atau chat Jalur B sesudah satu runner terpilih).
  ///
  /// Selama beberapa runner menawar bersamaan pada order yang sama,
  /// masing-masing punya obrolannya sendiri dengan klien; nilai ini yang
  /// memisahkannya.
  final String? runnerId;

  final MessageSender pengirim;
  final String isi;
  final DateTime dikirimPada;
  final String? fotoUrl;
}
