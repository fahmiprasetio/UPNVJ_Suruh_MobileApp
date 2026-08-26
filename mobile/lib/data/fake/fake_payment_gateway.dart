import 'dart:async';

import '../../core/config/tarif_config.dart';
import '../../domain/enums.dart';
import '../../domain/models/transaksi_pembayaran.dart';
import '../../domain/repositories/payment_gateway.dart';

/// Tiruan payment gateway untuk masa sebelum backend diputuskan.
///
/// Yang ditiru **hanya** pengirim konfirmasinya. Semua sifat lain dibuat sama
/// dengan gateway sungguhan, karena itulah bagian yang mudah salah kalau baru
/// dipikirkan belakangan:
///
///   - Satu order hanya boleh punya satu transaksi yang menunggu. Membuka
///     ulang layar bayar tidak melahirkan QR baru.
///   - Transaksi punya batas waktu dan hangus sendiri saat lewat, tanpa perlu
///     ada yang membuka layarnya.
///   - Status hanya boleh berubah dari sisi gateway. Tidak ada satu pun jalan
///     bagi klien untuk menyatakan dirinya sudah membayar.
///
/// [simulasikanPembayaranMasuk] adalah padanan halaman simulator di sandbox
/// Midtrans, alat penguji, bukan bagian dari aplikasi klien.
class FakePaymentGateway implements PaymentGateway {
  FakePaymentGateway();

  static const Duration _jedaJaringan = Duration(milliseconds: 400);

  final Map<String, TransaksiPembayaran> _transaksi = {};
  final Map<String, StreamController<TransaksiPembayaran>> _pancaran = {};
  final Map<String, Timer> _pewaktuKedaluwarsa = {};

  int _nomorUrut = 1;

  @override
  Future<TransaksiPembayaran> buatTransaksi({
    required String orderId,
    required int jumlah,
  }) async {
    await Future<void>.delayed(_jedaJaringan);

    final adaYangMenunggu = _transaksi.values
        .where((t) => t.orderId == orderId && t.menunggu)
        .firstOrNull;
    if (adaYangMenunggu != null) return adaYangMenunggu;

    final sekarang = DateTime.now();
    final id = 'trx-${_nomorUrut++}-${sekarang.microsecondsSinceEpoch}';
    final transaksi = TransaksiPembayaran(
      id: id,
      orderId: orderId,
      jumlah: jumlah,
      status: PaymentStatus.pending,
      qrisPayload: _payloadSimulasi(id: id, orderId: orderId, jumlah: jumlah),
      dibuatPada: sekarang,
      kedaluwarsaPada: sekarang.add(TarifConfig.batasWaktuBayar),
    );

    _transaksi[id] = transaksi;
    _pewaktuKedaluwarsa[id] = Timer(
      TarifConfig.batasWaktuBayar,
      () => _ubahStatus(id, PaymentStatus.kedaluwarsa),
    );
    return transaksi;
  }

  @override
  Stream<TransaksiPembayaran> watchTransaksi(String transaksiId) async* {
    final awal = _transaksi[transaksiId];
    if (awal == null) {
      throw StateError('Transaksi $transaksiId tidak ditemukan');
    }
    yield awal;
    yield* _kanal(transaksiId).stream;
  }

  @override
  Future<void> batalkanTransaksi(String transaksiId) async {
    await Future<void>.delayed(_jedaJaringan);
    _ubahStatus(transaksiId, PaymentStatus.gagal);
  }

  /// Padanan tombol "bayar" di halaman simulator sandbox.
  ///
  /// Di produksi peran ini dipegang bank atau e-wallet klien, dan hasilnya
  /// sampai ke sistem lewat webhook. Tidak boleh pernah dipanggil dari layar
  /// klien.
  void simulasikanPembayaranMasuk(String transaksiId) {
    _ubahStatus(transaksiId, PaymentStatus.berhasil);
  }

  void _ubahStatus(String transaksiId, PaymentStatus status) {
    final transaksi = _transaksi[transaksiId];
    // Status akhir tidak boleh dianulir, pembayaran yang sudah berhasil tetap
    // berhasil walau pewaktu kedaluwarsa ikut berbunyi setelahnya.
    if (transaksi == null || !transaksi.menunggu) return;

    final diperbarui = transaksi.copyWith(
      status: status,
      dibayarPada: status == PaymentStatus.berhasil ? DateTime.now() : null,
    );
    _transaksi[transaksiId] = diperbarui;
    _pewaktuKedaluwarsa.remove(transaksiId)?.cancel();

    final kanal = _pancaran[transaksiId];
    if (kanal != null && !kanal.isClosed) kanal.add(diperbarui);
  }

  StreamController<TransaksiPembayaran> _kanal(String transaksiId) =>
      _pancaran.putIfAbsent(
        transaksiId,
        () => StreamController<TransaksiPembayaran>.broadcast(),
      );

  /// Isi QR yang sengaja ditandai sebagai simulasi.
  ///
  /// Tidak dibuat menyerupai payload QRIS resmi. String yang mirip aslinya
  /// tapi palsu akan lolos pandangan sekilas dan menipu penguji; yang seperti
  /// ini gagal dipindai aplikasi bank, dan memang seharusnya begitu.
  static String _payloadSimulasi({
    required String id,
    required String orderId,
    required int jumlah,
  }) => 'SIMULASI-QRIS|trx=$id|order=$orderId|jumlah=$jumlah';

  void dispose() {
    for (final pewaktu in _pewaktuKedaluwarsa.values) {
      pewaktu.cancel();
    }
    _pewaktuKedaluwarsa.clear();
    for (final kanal in _pancaran.values) {
      kanal.close();
    }
    _pancaran.clear();
  }
}
