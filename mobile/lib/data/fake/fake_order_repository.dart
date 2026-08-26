import 'dart:async';
import 'dart:math';

import '../../domain/enums.dart';
import '../../domain/models/order.dart';
import '../../domain/repositories/order_repository.dart';
import 'seed_data.dart';

/// Implementasi [OrderRepository] yang menyimpan semuanya di memori.
///
/// Dipakai supaya seluruh antarmuka bisa dibangun dan diuji sebelum pilihan
/// stack backend dikunci. Setiap operasi diberi jeda kecil agar layar
/// benar-benar melewati keadaan memuat — bug "lupa menangani loading" jadi
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
      // Jalur A melewati dua status pertama — harga sudah pasti sejak awal.
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
      jumlahRunnerDibutuhkan: jumlahRunnerDibutuhkan,
    );
    _orders.add(order);
    _pancarkan();
    return order;
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

  void dispose() => _controller.close();

  String _idBaru() =>
      'o-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(999)}';

  String _kodeOrderBaru() => 'SRH-${(_nomorUrut++).toString().padLeft(4, '0')}';

  String _namaKlien(String klienId) =>
      SeedData.semuaUser.where((u) => u.id == klienId).firstOrNull?.nama ??
      'Klien';
}
