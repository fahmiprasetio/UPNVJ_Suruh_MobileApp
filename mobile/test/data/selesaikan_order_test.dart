import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';

/// Aturan penutupan order oleh runner.
///
/// Sama seperti anti-rebutan: yang menegakkan bukan layar, melainkan lapisan
/// data. Tombol yang disembunyikan tidak menghentikan siapa pun yang memanggil
/// langsung, jadi setiap syarat di sini harus punya tesnya sendiri.
void main() {
  Order orderDikerjakan({
    List<String> runnerIds = const ['u-runner-1'],
    OrderStatus status = OrderStatus.dikerjakan,
    int jumlahRunnerDibutuhkan = 1,
  }) {
    return Order(
      id: 'o-uji',
      kodeOrder: 'SRH-9001',
      klienId: 'u-klien-1',
      namaKlien: 'Dina Rahmawati',
      serviceType: ServiceType.anterJemput,
      status: status,
      dibuatPada: DateTime.now(),
      harga: 11000,
      jumlahRunnerDibutuhkan: jumlahRunnerDibutuhkan,
      runnerIds: runnerIds,
    );
  }

  test('runner yang memegang order bisa menutupnya dengan foto bukti', () async {
    final repo = FakeOrderRepository(orderAwal: [orderDikerjakan()]);
    addTearDown(repo.dispose);

    final order = await repo.selesaikanOrderSebagai(
      orderId: 'o-uji',
      runnerId: 'u-runner-1',
      fotoBuktiUrl: 'fake://bukti/o-uji.jpg',
      catatanSerahTerima: 'Dititipkan ke penjaga kos',
    );

    expect(order.status, OrderStatus.selesai);
    expect(order.fotoBuktiUrl, 'fake://bukti/o-uji.jpg');
    expect(order.catatanSerahTerima, 'Dititipkan ke penjaga kos');
    expect(order.selesaiPada, isNotNull);
  });

  test('runner yang tidak memegang order tidak bisa menutupnya', () async {
    final repo = FakeOrderRepository(orderAwal: [orderDikerjakan()]);
    addTearDown(repo.dispose);

    await expectLater(
      repo.selesaikanOrderSebagai(
        orderId: 'o-uji',
        runnerId: 'u-runner-lain',
        fotoBuktiUrl: 'fake://bukti/curang.jpg',
      ),
      throwsStateError,
    );

    expect(
      (await repo.watchOrder('o-uji').first)!.status,
      OrderStatus.dikerjakan,
    );
  });

  test('order yang masih mencari runner belum bisa diselesaikan', () async {
    final repo = FakeOrderRepository(
      orderAwal: [
        orderDikerjakan(
          status: OrderStatus.mencariRunner,
          jumlahRunnerDibutuhkan: 2,
        ),
      ],
    );
    addTearDown(repo.dispose);

    await expectLater(
      repo.selesaikanOrderSebagai(
        orderId: 'o-uji',
        runnerId: 'u-runner-1',
        fotoBuktiUrl: 'fake://bukti/o-uji.jpg',
      ),
      throwsStateError,
    );
  });

  test('order yang sudah selesai tidak bisa diselesaikan dua kali', () async {
    final repo = FakeOrderRepository(orderAwal: [orderDikerjakan()]);
    addTearDown(repo.dispose);

    await repo.selesaikanOrderSebagai(
      orderId: 'o-uji',
      runnerId: 'u-runner-1',
      fotoBuktiUrl: 'fake://bukti/o-uji.jpg',
    );

    await expectLater(
      repo.selesaikanOrderSebagai(
        orderId: 'o-uji',
        runnerId: 'u-runner-1',
        fotoBuktiUrl: 'fake://bukti/lagi.jpg',
      ),
      throwsStateError,
    );
  });

  test('order multi-runner boleh ditutup runner mana pun yang ditugaskan', () async {
    // Keputusan sementara sampai mitra menjawab siapa yang berhak menekan
    // selesai kalau pekerjaannya dibagi bertiga (bagian 14.7d).
    final repo = FakeOrderRepository(
      orderAwal: [
        orderDikerjakan(
          runnerIds: const ['u-runner-1', 'u-runner-2'],
          jumlahRunnerDibutuhkan: 2,
        ),
      ],
    );
    addTearDown(repo.dispose);

    final order = await repo.selesaikanOrderSebagai(
      orderId: 'o-uji',
      runnerId: 'u-runner-2',
      fotoBuktiUrl: 'fake://bukti/o-uji.jpg',
    );

    expect(order.status, OrderStatus.selesai);
  });

  test('order yang selesai keluar dari daftar order aktif runner', () async {
    final repo = FakeOrderRepository(orderAwal: [orderDikerjakan()]);
    addTearDown(repo.dispose);

    await repo.selesaikanOrderSebagai(
      orderId: 'o-uji',
      runnerId: 'u-runner-1',
      fotoBuktiUrl: 'fake://bukti/o-uji.jpg',
    );

    // Tetap terdaftar sebagai order runner, riwayatnya tidak hilang, tapi
    // tidak lagi terhitung sebagai pekerjaan berjalan.
    final punyaRunner = await repo.watchOrderRunnerUntuk('u-runner-1').first;
    expect(punyaRunner.isi, hasLength(1));
    expect(punyaRunner.total, 1);
    expect(punyaRunner.isi.where((o) => o.status.isAktif), isEmpty);
  });
}
