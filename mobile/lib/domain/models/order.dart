import 'package:flutter/foundation.dart';

import '../enums.dart';
import 'order_message.dart';
import 'order_offer.dart';
import 'payment.dart';

/// Satu order, dari permintaan sampai selesai.
///
/// Harga disimpan sebagai [int] rupiah penuh, tidak ada sen di rupiah, dan
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
    this.hargaUsulan,
    this.estimasiDurasi,
    this.jadwalMulai,
    this.jumlahRunnerDibutuhkan = 1,
    this.runnerIds = const [],
    this.fotoBuktiUrl,
    this.catatanSerahTerima,
    this.dibayarPada,
    this.selesaiPada,
    this.offers = const [],
    this.messages = const [],
    this.payment,
    this.jumlahPesan = 0,
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

  /// Harga yang disanggupi klien saat membuat permintaan Jalur B, sebelum ada
  /// runner yang menawar. Bukan harga order, cuma titik awal tawar-menawar
  /// yang dipajang ke runner yang menimbang permintaan ini.
  final int? hargaUsulan;
  final Duration? estimasiDurasi;

  /// Kapan pekerjaannya dijadwalkan mulai.
  ///
  /// Jalur A tidak memakainya, ordernya dikerjakan sekarang juga. Jalur B
  /// mengisinya dua kali: waktu yang diminta klien ketika menulis
  /// permintaan, lalu waktu yang disepakati begitu salah satu penawaran
  /// runner disetujui.
  final DateTime? jadwalMulai;

  /// Pindah kos bisa butuh 2-3 runner sekaligus (bagian 5).
  final int jumlahRunnerDibutuhkan;
  final List<String> runnerIds;

  final String? fotoBuktiUrl;
  final String? catatanSerahTerima;
  final DateTime? dibayarPada;
  final DateTime? selesaiPada;

  final List<OrderOffer> offers;
  final List<OrderMessage> messages;

  /// Berapa pesan yang ada di chat order ini.
  ///
  /// Terpisah dari [messages] karena daftar order tidak membawa isi percakapannya,
  /// cuma jumlahnya: penanda "ada 3 pesan" tidak layak menuntut seluruh chat ikut
  /// terkirim, dan biayanya justru tumbuh saat aplikasinya mulai ramai dipakai.
  /// Di layar chat pesannya memang dimuat, dan [messages] terisi; di daftar ia
  /// kosong sementara angka ini tetap benar.
  final int jumlahPesan;
  final Payment? payment;

  OrderTrack get track => serviceType.track;

  /// Order tetap terbuka untuk runner sampai kuotanya penuh (bagian 5).
  bool get kuotaRunnerPenuh => runnerIds.length >= jumlahRunnerDibutuhkan;

  int get sisaKuotaRunner =>
      (jumlahRunnerDibutuhkan - runnerIds.length).clamp(0, jumlahRunnerDibutuhkan);

  /// Seluruh penawaran yang masih menunggu jawaban klien, dari runner mana pun.
  ///
  /// Bisa lebih dari satu: beberapa runner boleh menawar order Jalur B yang
  /// sama secara bersamaan, mirip tawar-menawar di aplikasi ojek daring.
  /// Diurutkan termurah dulu, supaya klien langsung melihat tawaran paling
  /// menarik di atas.
  List<OrderOffer> get penawaranPending {
    final pending = offers
        .where((o) => o.status == OfferStatus.pending)
        .toList();
    pending.sort((a, b) => a.harga.compareTo(b.harga));
    return pending;
  }

  /// Penawaran terakhir yang diajukan satu runner tertentu pada order ini,
  /// atau `null` kalau ia belum pernah menawar.
  ///
  /// Dipakai runner untuk melihat status tawarannya sendiri: menunggu,
  /// disetujui, ditolak, ditutup (klien memilih runner lain), atau diminta
  /// nego ulang.
  OrderOffer? penawaranMilikRunner(String runnerId) {
    final milik = offers.where((o) => o.runnerId == runnerId).toList();
    return milik.isEmpty ? null : milik.last;
  }

  Order copyWith({
    OrderStatus? status,
    String? deskripsi,
    String? alamatJemput,
    String? alamatTujuan,
    int? harga,
    int? hargaUsulan,
    Duration? estimasiDurasi,
    DateTime? jadwalMulai,
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
      hargaUsulan: hargaUsulan ?? this.hargaUsulan,
      estimasiDurasi: estimasiDurasi ?? this.estimasiDurasi,
      jadwalMulai: jadwalMulai ?? this.jadwalMulai,
      jumlahRunnerDibutuhkan:
          jumlahRunnerDibutuhkan ?? this.jumlahRunnerDibutuhkan,
      runnerIds: runnerIds ?? this.runnerIds,
      fotoBuktiUrl: fotoBuktiUrl ?? this.fotoBuktiUrl,
      catatanSerahTerima: catatanSerahTerima ?? this.catatanSerahTerima,
      dibayarPada: dibayarPada ?? this.dibayarPada,
      selesaiPada: selesaiPada ?? this.selesaiPada,
      offers: offers ?? this.offers,
      messages: messages ?? this.messages,
      // Kalau daftar pesannya diganti, jumlahnya ikut dihitung ulang dari daftar
      // baru itu; kalau tidak, angka dari server dipertahankan apa adanya.
      jumlahPesan: messages?.length ?? jumlahPesan,
      payment: payment ?? this.payment,
    );
  }
}
