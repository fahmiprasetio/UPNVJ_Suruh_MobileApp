import 'dart:async';
import 'dart:math';

import '../../domain/enums.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_message.dart';
import '../../domain/models/order_offer.dart';
import '../../domain/repositories/order_repository.dart';
import 'seed_data.dart';

/// Implementasi [OrderRepository] yang menyimpan semuanya di memori.
///
/// Dipakai supaya seluruh antarmuka bisa dibangun dan diuji sebelum pilihan
/// stack backend dikunci. Setiap operasi diberi jeda kecil agar layar
/// benar-benar melewati keadaan memuat, bug "lupa menangani loading" jadi
/// ketahuan sekarang, bukan nanti saat server asli dipasang.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({List<Order>? orderAwal})
    : _orders = List.of(orderAwal ?? SeedData.orderAwal());

  static const Duration _jedaJaringan = Duration(milliseconds: 350);

  final List<Order> _orders;
  final StreamController<List<Order>> _controller =
      StreamController<List<Order>>.broadcast();
  final Random _random = Random();

  int _nomorUrut = 412;

  /// Snapshot sekarang lalu setiap perubahan sesudahnya.
  Stream<List<Order>> get _stream async* {
    yield List.unmodifiable(_orders);
    yield* _controller.stream;
  }

  void _pancarkan() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_orders));
    }
  }

  void _ganti(Order baru) {
    final indeks = _orders.indexWhere((o) => o.id == baru.id);
    if (indeks == -1) {
      throw StateError('Order ${baru.id} tidak ditemukan');
    }
    _orders[indeks] = baru;
    _pancarkan();
  }

  Order _wajibAda(String orderId) {
    final order = _orders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) {
      throw StateError('Order $orderId tidak ditemukan');
    }
    return order;
  }

  static List<Order> _terbaruDiAtas(List<Order> orders) =>
      List.of(orders)..sort((a, b) => b.dibuatPada.compareTo(a.dibuatPada));

  @override
  Stream<List<Order>> watchOrderKlien(String klienId) => _stream.map(
    (orders) =>
        _terbaruDiAtas(orders.where((o) => o.klienId == klienId).toList()),
  );

  @override
  Stream<List<Order>> watchOrderTersiar() => _stream.map(
    (orders) => _terbaruDiAtas(
      orders
          .where(
            (o) => o.status == OrderStatus.mencariRunner && !o.kuotaRunnerPenuh,
          )
          .toList(),
    ),
  );

  @override
  Stream<List<Order>> watchOrderRunner(String runnerId) => _stream.map(
    (orders) => _terbaruDiAtas(
      orders.where((o) => o.runnerIds.contains(runnerId)).toList(),
    ),
  );

  @override
  Stream<Order?> watchOrder(String orderId) =>
      _stream.map((orders) => orders.where((o) => o.id == orderId).firstOrNull);

  @override
  Future<Order?> getOrder(String orderId) async {
    await Future<void>.delayed(_jedaJaringan);
    return _orders.where((o) => o.id == orderId).firstOrNull;
  }

  @override
  Future<Order> buatOrderJalurA({
    required String klienId,
    required ServiceType serviceType,
    required int harga,
    String? deskripsi,
    String? alamatJemput,
    String? alamatTujuan,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = Order(
      id: _idBaru(),
      kodeOrder: _kodeOrderBaru(),
      klienId: klienId,
      namaKlien: _namaKlien(klienId),
      serviceType: serviceType,
      // Jalur A melewati dua status pertama, harga sudah pasti sejak awal.
      status: OrderStatus.menungguPembayaran,
      dibuatPada: DateTime.now(),
      deskripsi: deskripsi,
      alamatJemput: alamatJemput,
      alamatTujuan: alamatTujuan,
      harga: harga,
    );
    _orders.add(order);
    _pancarkan();
    return order;
  }

  @override
  Future<Order> buatPermintaanJalurB({
    required String klienId,
    required ServiceType serviceType,
    required String deskripsi,
    required DateTime jadwalMulai,
    String? alamatTujuan,
    int jumlahRunnerDibutuhkan = 1,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = Order(
      id: _idBaru(),
      kodeOrder: _kodeOrderBaru(),
      klienId: klienId,
      namaKlien: _namaKlien(klienId),
      serviceType: serviceType,
      status: OrderStatus.permintaan,
      dibuatPada: DateTime.now(),
      deskripsi: deskripsi,
      alamatTujuan: alamatTujuan,
      jadwalMulai: jadwalMulai,
      jumlahRunnerDibutuhkan: jumlahRunnerDibutuhkan,
    );
    _orders.add(order);
    _pancarkan();
    return order;
  }

  @override
  Future<Order> buatPenawaran({
    required String orderId,
    required int harga,
    required Duration estimasiDurasi,
    required DateTime jadwalMulai,
    String? catatan,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);

    if (order.track != OrderTrack.jalurB) {
      throw StateError(
        'Order ${order.kodeOrder} bukan Jalur B, harganya sudah pasti sejak '
        'order dibuat',
      );
    }
    // Hanya permintaan yang belum punya penawaran menunggu yang boleh
    // ditawari. Tanpa syarat ini, penawaran kedua akan diam-diam menimpa
    // penawaran yang sedang dibaca klien, dan klien menekan setuju untuk harga
    // yang berbeda dari yang tampil di layarnya.
    if (order.status != OrderStatus.permintaan) {
      throw StateError(
        'Order ${order.kodeOrder} sedang ${order.status.label}, '
        'bukan permintaan yang menunggu penawaran',
      );
    }
    if (harga <= 0) {
      throw StateError('Harga penawaran harus lebih dari nol');
    }

    final penawaran = OrderOffer(
      id: 'p-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(999)}',
      orderId: orderId,
      harga: harga,
      estimasiDurasi: estimasiDurasi,
      jadwalMulai: jadwalMulai,
      dibuatPada: DateTime.now(),
      status: OfferStatus.pending,
      catatan: catatan,
    );
    // Harga ordernya sengaja tidak diisi di sini, lihat alasannya di kontrak.
    final diperbarui = order.copyWith(
      status: OrderStatus.menungguPersetujuanKlien,
      offers: [...order.offers, penawaran],
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> setujuiPenawaran(String orderId) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);
    final penawaran = _penawaranMenunggu(order);

    final diperbarui = order.copyWith(
      status: OrderStatus.menungguPembayaran,
      harga: penawaran.harga,
      estimasiDurasi: penawaran.estimasiDurasi,
      jadwalMulai: penawaran.jadwalMulai,
      offers: _gantiPenawaran(order, penawaran, OfferStatus.disetujui),
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> tolakPenawaran(String orderId) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);
    final penawaran = _penawaranMenunggu(order);

    final diperbarui = order.copyWith(
      status: OrderStatus.batal,
      offers: _gantiPenawaran(order, penawaran, OfferStatus.ditolak),
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> ajukanNego({
    required String orderId,
    required String alasan,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);
    final penawaran = _penawaranMenunggu(order);

    final bersih = alasan.trim();
    if (bersih.isEmpty) {
      throw StateError(
        'Nego tanpa alasan tidak bisa dikirim, admin tidak punya bahan untuk '
        'menghitung ulang',
      );
    }

    // Alasannya masuk ke chat ordernya, bukan ke kolom tersembunyi di
    // penawaran, supaya admin menjawabnya di tempat yang sama dengan
    // pertanyaan lain tentang order ini.
    final pesan = OrderMessage(
      id: 'm-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(999)}',
      orderId: orderId,
      pengirim: MessageSender.klien,
      isi: bersih,
      dikirimPada: DateTime.now(),
    );
    final diperbarui = order.copyWith(
      // Kembali ke antrean admin, bukan batal: klien masih berminat.
      status: OrderStatus.permintaan,
      offers: _gantiPenawaran(order, penawaran, OfferStatus.dinegoUlang),
      messages: [...order.messages, pesan],
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  /// Penawaran yang sedang menunggu jawaban, atau galat kalau tidak ada.
  ///
  /// Pemeriksaannya di sini, bukan di layar, karena tombol yang disembunyikan
  /// tidak menghentikan siapa pun yang memanggil langsung.
  OrderOffer _penawaranMenunggu(Order order) {
    final penawaran = order.penawaranMenunggu;
    if (penawaran == null) {
      throw StateError(
        'Order ${order.kodeOrder} tidak punya penawaran yang menunggu jawaban',
      );
    }
    return penawaran;
  }

  static List<OrderOffer> _gantiPenawaran(
    Order order,
    OrderOffer penawaran,
    OfferStatus status,
  ) {
    return [
      for (final o in order.offers)
        if (o.id == penawaran.id) o.copyWith(status: status) else o,
    ];
  }

  @override
  Future<Order> tandaiSudahDibayar(String orderId) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);
    if (order.status != OrderStatus.menungguPembayaran) {
      throw StateError(
        'Order ${order.kodeOrder} tidak sedang menunggu pembayaran '
        '(status sekarang: ${order.status.label})',
      );
    }
    final diperbarui = order.copyWith(
      status: OrderStatus.mencariRunner,
      dibayarPada: DateTime.now(),
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<bool> terimaOrder({
    required String orderId,
    required String runnerId,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);

    // Cerminan dari UPDATE ... WHERE status = MENCARI_RUNNER di basis data:
    // kalau syaratnya tidak lagi terpenuhi, runner ini kalah cepat.
    if (order.status != OrderStatus.mencariRunner) return false;
    if (order.kuotaRunnerPenuh) return false;
    if (order.runnerIds.contains(runnerId)) return false;

    final runnerBaru = [...order.runnerIds, runnerId];
    final kuotaPenuh = runnerBaru.length >= order.jumlahRunnerDibutuhkan;
    _ganti(
      order.copyWith(
        runnerIds: runnerBaru,
        status: kuotaPenuh ? OrderStatus.dikerjakan : OrderStatus.mencariRunner,
      ),
    );
    return true;
  }

  @override
  Future<Order> selesaikanOrder({
    required String orderId,
    required String runnerId,
    required String fotoBuktiUrl,
    String? catatanSerahTerima,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);
    if (order.status != OrderStatus.dikerjakan) {
      throw StateError(
        'Order ${order.kodeOrder} belum dikerjakan, tidak bisa diselesaikan',
      );
    }
    if (!order.runnerIds.contains(runnerId)) {
      throw StateError(
        'Runner $runnerId tidak memegang order ${order.kodeOrder}',
      );
    }
    // Pada order multi-runner, runner mana pun yang ditugaskan boleh menutup
    // order. Ini keputusan sementara: siapa yang berhak menekan selesai kalau
    // pekerjaannya dibagi tiga orang masih menunggu jawaban mitra (bagian
    // 14.7d).
    final diperbarui = order.copyWith(
      status: OrderStatus.selesai,
      fotoBuktiUrl: fotoBuktiUrl,
      catatanSerahTerima: catatanSerahTerima,
      selesaiPada: DateTime.now(),
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> batalkanOrder(String orderId) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);
    if (!order.status.isAktif) {
      throw StateError('Order ${order.kodeOrder} sudah ${order.status.label}');
    }
    final diperbarui = order.copyWith(status: OrderStatus.batal);
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> kirimPesan({
    required String orderId,
    required MessageSender pengirim,
    required String isi,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);

    final bersih = isi.trim();
    if (bersih.isEmpty) {
      throw StateError('Pesan kosong tidak bisa dikirim');
    }
    // Order yang sudah selesai atau batal tidak boleh dihidupkan lagi lewat
    // chat. Kalau masih ada urusan, urusan itu butuh order baru atau campur
    // tangan admin, bukan percakapan yang menempel pada pekerjaan yang sudah
    // ditutup.
    if (!order.status.isAktif) {
      throw StateError(
        'Order ${order.kodeOrder} sudah ${order.status.label}, '
        'chatnya ikut ditutup',
      );
    }

    final pesan = OrderMessage(
      id: 'm-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(999)}',
      orderId: orderId,
      pengirim: pengirim,
      isi: bersih,
      dikirimPada: DateTime.now(),
    );
    final diperbarui = order.copyWith(messages: [...order.messages, pesan]);
    _ganti(diperbarui);
    return diperbarui;
  }

  void dispose() => _controller.close();

  String _idBaru() =>
      'o-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(999)}';

  String _kodeOrderBaru() => 'SRH-${(_nomorUrut++).toString().padLeft(4, '0')}';

  String _namaKlien(String klienId) =>
      SeedData.semuaUser.where((u) => u.id == klienId).firstOrNull?.nama ??
      'Klien';
}
