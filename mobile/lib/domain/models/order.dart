import 'package:flutter/foundation.dart';

import '../enums.dart';
import 'order_message.dart';
import 'order_offer.dart';
import 'payment.dart';
import 'runner_ringkas.dart';

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
    this.jarakKm,
    this.harga,
    this.hargaUsulan,
    this.estimasiDurasi,
    this.jadwalMulai,
    this.jumlahRunnerDibutuhkan = 1,
    this.runners = const [],
    this.fotoBuktiUrl,
    this.catatanSerahTerima,
    this.dibayarPada,
    this.selesaiPada,
    this.mintaBatalPada,
    this.macet = false,
    this.offers = const [],
    this.messages = const [],
    this.payment,
    this.jumlahPesan = 0,
    this.jumlahPesanBelumDibaca = 0,
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

  /// Perkiraan jarak yang diisi klien saat membuat order Jalur A.
  ///
  /// Dipegang walaupun tidak satu layar pun menampilkannya: harga sudah
  /// dibekukan di [harga], jadi angka ini tidak dipakai menghitung apa pun
  /// lagi. Yang membutuhkannya adalah "Pesan lagi", yang harus bisa mengisi
  /// ulang kolom jarak persis seperti yang dulu diketik pemiliknya.
  final double? jarakKm;

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

  /// Runner yang sudah menerima order ini, lengkap dengan nama dan nomor HP.
  final List<RunnerRingkas> runners;

  /// Id runner yang sudah menerima order ini, diturunkan dari [runners].
  ///
  /// Dipertahankan sebagai getter terpisah karena sebagian besar pemeriksaan
  /// ("apakah runner ini sudah memegang order ini", "berapa slot yang sudah
  /// terisi") cuma butuh id, bukan nama atau nomor HP. Diturunkan, bukan
  /// disimpan sebagai kolom terpisah, supaya keduanya tidak bisa berselisih.
  List<String> get runnerIds => [for (final r in runners) r.id];

  final String? fotoBuktiUrl;
  final String? catatanSerahTerima;
  final DateTime? dibayarPada;
  final DateTime? selesaiPada;

  /// Terisi selama ada permintaan pembatalan yang belum dijawab admin.
  ///
  /// Order yang sudah dibayar tidak bisa dibatalkan klien sendiri, karena ada uang
  /// yang harus kembali. Yang bisa ia lakukan meminta, dan nilai inilah yang
  /// membedakan "belum pernah meminta" dari "sudah, tinggal menunggu jawaban".
  final DateTime? mintaBatalPada;

  /// Benar kalau order ini sudah terlalu lama menganggur tanpa runner.
  ///
  /// Dihitung server, bukan di sini. Ambangnya aturan sistem (`OrderMacet` di backend),
  /// bukan angka milik satu layar, dan menghitungnya sendiri di dua permukaan berarti
  /// aplikasi dan dashboard bisa berbeda pendapat tentang order yang sama.
  final bool macet;

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

  /// Dari [jumlahPesan], berapa yang belum dibaca pengguna yang sedang masuk.
  ///
  /// Dihitung server dari penanda baca per jalur obrolan (bagian 10 rencana capstone),
  /// bukan ditebak di sini: aplikasi tidak menyimpan sendiri pesan mana yang sudah
  /// dilihat, cuma menampilkan angka yang dikirim server apa adanya.
  final int jumlahPesanBelumDibaca;
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
    List<RunnerRingkas>? runners,
    String? fotoBuktiUrl,
    String? catatanSerahTerima,
    DateTime? dibayarPada,
    DateTime? selesaiPada,
    DateTime? mintaBatalPada,
    bool? macet,
    List<OrderOffer>? offers,
    List<OrderMessage>? messages,
    Payment? payment,
    int? jumlahPesanBelumDibaca,
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
      jarakKm: jarakKm,
      harga: harga ?? this.harga,
      hargaUsulan: hargaUsulan ?? this.hargaUsulan,
      estimasiDurasi: estimasiDurasi ?? this.estimasiDurasi,
      jadwalMulai: jadwalMulai ?? this.jadwalMulai,
      jumlahRunnerDibutuhkan:
          jumlahRunnerDibutuhkan ?? this.jumlahRunnerDibutuhkan,
      runners: runners ?? this.runners,
      fotoBuktiUrl: fotoBuktiUrl ?? this.fotoBuktiUrl,
      catatanSerahTerima: catatanSerahTerima ?? this.catatanSerahTerima,
      dibayarPada: dibayarPada ?? this.dibayarPada,
      selesaiPada: selesaiPada ?? this.selesaiPada,
      mintaBatalPada: mintaBatalPada ?? this.mintaBatalPada,
      macet: macet ?? this.macet,
      offers: offers ?? this.offers,
      messages: messages ?? this.messages,
      // Kalau daftar pesannya diganti, jumlahnya ikut dihitung ulang dari daftar
      // baru itu; kalau tidak, angka dari server dipertahankan apa adanya.
      jumlahPesan: messages?.length ?? jumlahPesan,
      jumlahPesanBelumDibaca:
          jumlahPesanBelumDibaca ?? this.jumlahPesanBelumDibaca,
      payment: payment ?? this.payment,
    );
  }
}
