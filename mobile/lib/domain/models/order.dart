import 'package:flutter/foundation.dart';

import '../enums.dart';
import 'order_message.dart';
import 'order_offer.dart';
import 'payment.dart';

/// Satu order, dari permintaan sampai selesai.
///
/// Harga disimpan sebagai [int] rupiah penuh — tidak ada sen di rupiah, dan
/// `double` untuk uang adalah sumber galat pembulatan.
@immutable
class Order {
  const Order({
    required this.id,
    required this.kodeOrder,
    required this.klienId,
    required this.namaKlien,
    required this.serviceType,
    required this.status,
    required this.dibuatPada,
    this.deskripsi,
    this.alamatJemput,
    this.alamatTujuan,
    this.harga,
    this.estimasiDurasi,
    this.jumlahRunnerDibutuhkan = 1,
    this.runnerIds = const [],
    this.fotoBuktiUrl,
    this.catatanSerahTerima,
    this.dibayarPada,
    this.selesaiPada,
    this.offers = const [],
    this.messages = const [],
    this.payment,
  });

  final String id;

  /// Kode pendek yang dibaca manusia, misal `SRH-0412`.
  final String kodeOrder;
  final String klienId;
  final String namaKlien;
  final ServiceType serviceType;
  final OrderStatus status;
  final DateTime dibuatPada;

  final String? deskripsi;
  final String? alamatJemput;
  final String? alamatTujuan;

  /// Rupiah penuh. `null` selama harga belum disepakati (Jalur B).
  final int? harga;
  final Duration? estimasiDurasi;

  /// Pindah kos bisa butuh 2-3 runner sekaligus (bagian 5).
  final int jumlahRunnerDibutuhkan;
  final List<String> runnerIds;

  final String? fotoBuktiUrl;
  final String? catatanSerahTerima;
  final DateTime? dibayarPada;
  final DateTime? selesaiPada;

  final List<OrderOffer> offers;
  final List<OrderMessage> messages;
  final Payment? payment;

  OrderTrack get track => serviceType.track;

  /// Order tetap terbuka untuk runner sampai kuotanya penuh (bagian 5).
  bool get kuotaRunnerPenuh => runnerIds.length >= jumlahRunnerDibutuhkan;

  int get sisaKuotaRunner =>
      (jumlahRunnerDibutuhkan - runnerIds.length).clamp(0, jumlahRunnerDibutuhkan);

  /// Penawaran terbaru dari admin, kalau ada.
  OrderOffer? get penawaranTerakhir => offers.isEmpty ? null : offers.last;

  Order copyWith({
    OrderStatus? status,
    String? deskripsi,
    String? alamatJemput,
    String? alamatTujuan,
    int? harga,
    Duration? estimasiDurasi,
    int? jumlahRunnerDibutuhkan,
    List<String>? runnerIds,
    String? fotoBuktiUrl,
    String? catatanSerahTerima,
    DateTime? dibayarPada,
    DateTime? selesaiPada,
    List<OrderOffer>? offers,
    List<OrderMessage>? messages,
    Payment? payment,
  }) {
    return Order(
      id: id,
      kodeOrder: kodeOrder,
      klienId: klienId,
      namaKlien: namaKlien,
      serviceType: serviceType,
      status: status ?? this.status,
      dibuatPada: dibuatPada,
      deskripsi: deskripsi ?? this.deskripsi,
      alamatJemput: alamatJemput ?? this.alamatJemput,
      alamatTujuan: alamatTujuan ?? this.alamatTujuan,
      harga: harga ?? this.harga,
      estimasiDurasi: estimasiDurasi ?? this.estimasiDurasi,
      jumlahRunnerDibutuhkan:
          jumlahRunnerDibutuhkan ?? this.jumlahRunnerDibutuhkan,
      runnerIds: runnerIds ?? this.runnerIds,
      fotoBuktiUrl: fotoBuktiUrl ?? this.fotoBuktiUrl,
      catatanSerahTerima: catatanSerahTerima ?? this.catatanSerahTerima,
      dibayarPada: dibayarPada ?? this.dibayarPada,
      selesaiPada: selesaiPada ?? this.selesaiPada,
      offers: offers ?? this.offers,
      messages: messages ?? this.messages,
      payment: payment ?? this.payment,
    );
  }
}
