import 'package:flutter/foundation.dart';

import '../enums.dart';

/// Satu transaksi di payment gateway.
///
/// Bentuknya mengikuti apa yang benar-benar dikembalikan Midtrans/Xendit saat
/// membuat charge QRIS: id transaksi milik gateway, isi QR yang harus
/// digambar, batas waktu, dan status yang berubah sendiri di sisi gateway.
///
/// Klien tidak pernah menentukan [status]. Yang boleh mengubahnya cuma
/// gateway, di produksi lewat webhook ke server, dan itulah alasan integrasi
/// sungguhan tidak bisa hidup di dalam aplikasi saja.
@immutable
class TransaksiPembayaran {
  const TransaksiPembayaran({
    required this.id,
    required this.orderId,
    required this.jumlah,
    required this.status,
    required this.qrisPayload,
    required this.dibuatPada,
    required this.kedaluwarsaPada,
    this.dibayarPada,
  });

  /// Id milik gateway (Midtrans menyebutnya `transaction_id`).
  final String id;
  final String orderId;
  final int jumlah;
  final PaymentStatus status;

  /// Isi mentah kode QR, digambar apa adanya oleh aplikasi.
  ///
  /// Di produksi ini adalah string QRIS resmi dari gateway. Aplikasi tidak
  /// pernah menyusunnya sendiri, hanya menggambar apa yang diberikan.
  final String qrisPayload;

  final DateTime dibuatPada;
  final DateTime kedaluwarsaPada;
  final DateTime? dibayarPada;

  bool get menunggu => status == PaymentStatus.pending;
  bool get berhasil => status == PaymentStatus.berhasil;

  Duration sisaWaktu(DateTime sekarang) {
    final sisa = kedaluwarsaPada.difference(sekarang);
    return sisa.isNegative ? Duration.zero : sisa;
  }

  TransaksiPembayaran copyWith({
    PaymentStatus? status,
    DateTime? dibayarPada,
  }) {
    return TransaksiPembayaran(
      id: id,
      orderId: orderId,
      jumlah: jumlah,
      status: status ?? this.status,
      qrisPayload: qrisPayload,
      dibuatPada: dibuatPada,
      kedaluwarsaPada: kedaluwarsaPada,
      dibayarPada: dibayarPada ?? this.dibayarPada,
    );
  }
}
