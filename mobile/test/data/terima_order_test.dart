import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';

/// Tes anti-rebutan runner, inti teknis proyek (rencana capstone bagian 14.5).
///
/// Yang diuji di sini bukan tampilan, melainkan aturannya: satu slot hanya
/// boleh jatuh ke satu runner, walau dua orang menekan TERIMA pada detik yang
/// sama. Implementasi sungguhan nanti menegakkannya lewat satu perintah UPDATE
/// bersyarat di basis data; tes ini yang menentukan perilaku apa yang harus
/// dihasilkan perintah itu.
void main() {
  Order orderSiaran({
    String id = 'o-uji',
    int jumlahRunnerDibutuhkan = 1,
    List<String> runnerIds = const [],
    OrderStatus status = OrderStatus.mencariRunner,
  }) {
    return Order(
      id: id,
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

  test('dua runner menekan TERIMA bersamaan, hanya satu yang dapat', () async {
    final repo = FakeOrderRepository(orderAwal: [orderSiaran()]);
    addTearDown(repo.dispose);

    final hasil = await Future.wait([
      repo.terimaOrder(orderId: 'o-uji', runnerId: 'u-runner-1'),
      repo.terimaOrder(orderId: 'o-uji', runnerId: 'u-runner-2'),
    ]);

    expect(hasil.where((dapat) => dapat).length, 1);

    final order = await repo.getOrder('o-uji');
    expect(order!.runnerIds, hasLength(1));
    expect(order.status, OrderStatus.dikerjakan);
  });

  test('runner yang kalah cepat tidak menggeser runner yang sudah dapat', () async {
    final repo = FakeOrderRepository(orderAwal: [orderSiaran()]);
    addTearDown(repo.dispose);

    await repo.terimaOrder(orderId: 'o-uji', runnerId: 'u-runner-1');
    final dapat = await repo.terimaOrder(
      orderId: 'o-uji',
      runnerId: 'u-runner-2',
    );

    expect(dapat, isFalse);
    expect((await repo.getOrder('o-uji'))!.runnerIds, ['u-runner-1']);
  });

  test('order multi-runner tetap tersiar sampai kuotanya penuh', () async {
    final repo = FakeOrderRepository(
      orderAwal: [orderSiaran(jumlahRunnerDibutuhkan: 3)],
    );
    addTearDown(repo.dispose);

    await repo.terimaOrder(orderId: 'o-uji', runnerId: 'u-runner-1');
    await repo.terimaOrder(orderId: 'o-uji', runnerId: 'u-runner-2');

    var order = (await repo.getOrder('o-uji'))!;
    expect(order.status, OrderStatus.mencariRunner);
    expect(order.sisaKuotaRunner, 1);

    await repo.terimaOrder(orderId: 'o-uji', runnerId: 'u-runner-3');

    order = (await repo.getOrder('o-uji'))!;
    expect(order.status, OrderStatus.dikerjakan);
    expect(order.kuotaRunnerPenuh, isTrue);
  });

  test('kuota yang sudah penuh menolak runner keempat', () async {
    final repo = FakeOrderRepository(
      orderAwal: [
        orderSiaran(
          jumlahRunnerDibutuhkan: 2,
          runnerIds: const ['u-runner-1', 'u-runner-2'],
        ),
      ],
    );
    addTearDown(repo.dispose);

    expect(
      await repo.terimaOrder(orderId: 'o-uji', runnerId: 'u-runner-3'),
      isFalse,
    );
  });

  test('runner yang sama tidak bisa mengambil dua slot di order yang sama', () async {
    final repo = FakeOrderRepository(
      orderAwal: [orderSiaran(jumlahRunnerDibutuhkan: 3)],
    );
    addTearDown(repo.dispose);

    await repo.terimaOrder(orderId: 'o-uji', runnerId: 'u-runner-1');
    final lagi = await repo.terimaOrder(
      orderId: 'o-uji',
      runnerId: 'u-runner-1',
    );

    expect(lagi, isFalse);
    expect((await repo.getOrder('o-uji'))!.runnerIds, ['u-runner-1']);
  });

  test('order yang belum dibayar tidak boleh diambil runner', () async {
    // Aturan bayar di depan (bagian 7): order baru disiarkan setelah uangnya
    // masuk, jadi status apa pun sebelum itu harus ditolak.
    final repo = FakeOrderRepository(
      orderAwal: [orderSiaran(status: OrderStatus.menungguPembayaran)],
    );
    addTearDown(repo.dispose);

    expect(
      await repo.terimaOrder(orderId: 'o-uji', runnerId: 'u-runner-1'),
      isFalse,
    );
    expect(
      (await repo.getOrder('o-uji'))!.status,
      OrderStatus.menungguPembayaran,
    );
  });

  test('order tersiar berhenti disiarkan begitu diambil', () async {
    final repo = FakeOrderRepository(orderAwal: [orderSiaran()]);
    addTearDown(repo.dispose);

    final tersiar = repo.watchOrderTersiar('u-runner-1');
    expect(await tersiar.first, hasLength(1));

    await repo.terimaOrder(orderId: 'o-uji', runnerId: 'u-runner-1');

    expect(await repo.watchOrderTersiar('u-runner-1').first, isEmpty);
    expect(await repo.watchOrderRunner('u-runner-1').first, hasLength(1));
  });

  test('klien tidak bisa menerima ordernya sendiri', () async {
    // Akun yang memegang peran klien sekaligus runner (bagian 14.3) membuat
    // ini mungkin secara teknis. Kalau dibiarkan, satu orang bisa memesan,
    // menerima sendiri, lalu menagih upah atas pekerjaan yang tidak pernah
    // berpindah tangan.
    final repo = FakeOrderRepository(orderAwal: [orderSiaran()]);
    addTearDown(repo.dispose);

    await expectLater(
      repo.terimaOrder(orderId: 'o-uji', runnerId: 'u-klien-1'),
      throwsStateError,
    );

    final order = (await repo.getOrder('o-uji'))!;
    expect(order.runnerIds, isEmpty);
    expect(order.status, OrderStatus.mencariRunner);
  });

  test('order sendiri tidak ikut disiarkan ke pemesannya', () async {
    // Penolakan di atas adalah jaring terakhir. Yang menjaga lebih dulu adalah
    // siarannya: order milik sendiri tidak pernah sampai ke daftar order
    // masuk, jadi tombol TERIMA-nya tidak pernah ada untuk ditekan.
    final repo = FakeOrderRepository(orderAwal: [orderSiaran()]);
    addTearDown(repo.dispose);

    expect(await repo.watchOrderTersiar('u-klien-1').first, isEmpty);
    expect(await repo.watchOrderTersiar('u-runner-1').first, hasLength(1));
  });
}
