import 'dart:async';

import '../../core/config/tarif_config.dart';
import '../../domain/enums.dart';
import '../../domain/models/transaksi_pembayaran.dart';
import '../../domain/repositories/payment_gateway.dart';

/// Dari mana tiruan ini tahu berapa yang harus ditagih.
///
/// Gateway sungguhan tidak perlu bertanya: servernya membaca harga order dari
/// basis datanya sendiri. Tiruan ini tidak punya basis data, jadi ia dipasangkan
/// ke sumber harga dari luar, dengan pola yang sama seperti identitas pemanggil
/// pada tiruan repository order. Yang penting sama: jumlahnya tetap tidak
/// pernah datang dari layar.
typedef HargaOrder = Future<int?> Function(String orderId);

/// Tiruan payment gateway, dipakai saat aplikasi berjalan tanpa server.
///
/// Yang ditiru hanya pengirim konfirmasinya. Semua sifat lain dibuat sama dengan
/// gateway sungguhan, karena itulah bagian yang mudah salah kalau baru
/// dipikirkan belakangan:
///
///   - Satu order hanya boleh punya satu transaksi yang menunggu. Membuka ulang
///     layar bayar tidak melahirkan QR baru.
///   - Transaksi punya batas waktu dan hangus sendiri saat lewat, tanpa perlu
///     ada yang membuka layarnya.
///   - Status hanya boleh berubah dari sisi gateway. Tidak ada satu pun jalan
///     bagi klien untuk menyatakan dirinya sudah membayar.
///
/// [simulasikanPembayaranMasuk] adalah padanan halaman simulator di sandbox
/// Midtrans, alat penguji, bukan bagian dari aplikasi klien.
class FakePaymentGateway implements PaymentGateway {
  FakePaymentGateway({HargaOrder? hargaOrder})
    : _hargaOrder = hargaOrder ?? _hargaBawaan;

  static const Duration _jedaJaringan = Duration(milliseconds: 400);

  /// Dipakai tes yang cuma mengurus perilaku gatewaynya, bukan harganya.
  static Future<int?> _hargaBawaan(String orderId) async => 11000;

  final HargaOrder _hargaOrder;

  final Map<String, TransaksiPembayaran> _transaksi = {};
  final Map<String, StreamController<TransaksiPembayaran>> _pancaran = {};
  final Map<String, Timer> _pewaktuKedaluwarsa = {};

  int _nomorUrut = 1;

  @override
  Future<TransaksiPembayaran> buatTransaksi({required String orderId}) async {
    await Future<void>.delayed(_jedaJaringan);

    final adaYangMenunggu = _hidup(orderId);
    if (adaYangMenunggu != null) return adaYangMenunggu;

    final jumlah = await _hargaOrder(orderId);
    if (jumlah == null || jumlah <= 0) {
      throw StateError(
        'Order $orderId belum punya harga, belum bisa ditagihkan',
      );
    }

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
  Stream<TransaksiPembayaran> watchTransaksi(String orderId) async* {
    final awal = _terbaru(orderId);
    if (awal == null) {
      throw StateError('Order $orderId belum punya transaksi');
    }
    yield awal;
    yield* _kanal(awal.id).stream;
  }

  @override
  Future<void> batalkanTransaksi(String orderId) async {
    await Future<void>.delayed(_jedaJaringan);
    final hidup = _hidup(orderId);
    if (hidup != null) _ubahStatus(hidup.id, PaymentStatus.gagal);
  }

  /// Padanan tombol "bayar" di halaman simulator sandbox.
  ///
  /// Di produksi peran ini dipegang bank atau e-wallet klien, dan hasilnya sampai
  /// ke sistem lewat webhook. Tidak boleh pernah dipanggil dari layar klien.
  void simulasikanPembayaranMasuk(String orderId) {
    final hidup = _hidup(orderId);
    if (hidup != null) _ubahStatus(hidup.id, PaymentStatus.berhasil);
  }

  /// Transaksi order itu yang masih menunggu, kalau ada.
  TransaksiPembayaran? _hidup(String orderId) => _transaksi.values
      .where((t) => t.orderId == orderId && t.menunggu)
      .firstOrNull;

  /// Transaksi terakhir order itu, menunggu atau tidak.
  ///
  /// Yang menunggu selalu didahulukan: percobaan yang hangus tetap tersimpan,
  /// dan layar harus melihat yang sedang berlaku, bukan yang terakhir dibuat.
  TransaksiPembayaran? _terbaru(String orderId) {
    final hidup = _hidup(orderId);
    if (hidup != null) return hidup;
    final milikOrder = _transaksi.values.where((t) => t.orderId == orderId);
    if (milikOrder.isEmpty) return null;
    return milikOrder.reduce(
      (a, b) => b.dibuatPada.isAfter(a.dibuatPada) ? b : a,
    );
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
  /// Tidak dibuat menyerupai payload QRIS resmi. String yang mirip aslinya tapi
  /// palsu akan lolos pandangan sekilas dan menipu penguji; yang seperti ini
  /// gagal dipindai aplikasi bank, dan memang seharusnya begitu.
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
