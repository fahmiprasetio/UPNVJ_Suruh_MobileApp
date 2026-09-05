import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';

/// Klien meminta order yang sudah dibayar dibatalkan admin.
///
/// Aturannya diuji di sini, bukan lewat layar, dengan alasan yang sama seperti
/// `lepas_order_test.dart`: yang diperiksa keadaan tersimpannya, dan jam di dalam tes
/// widget tidak maju sendiri.
void main() {
  const klienId = 'u-klien-1';

  Order order({
    OrderStatus status = OrderStatus.dikerjakan,
    DateTime? dibayarPada,
    DateTime? mintaBatalPada,
  }) {
    return Order(
      id: 'o-uji',
      kodeOrder: 'SRH-9001',
      klienId: klienId,
      namaKlien: 'Dina Rahmawati',
      serviceType: ServiceType.anterJemput,
      status: status,
      dibuatPada: DateTime.now(),
      harga: 11000,
      dibayarPada: dibayarPada ?? DateTime.now(),
      mintaBatalPada: mintaBatalPada,
    );
  }

  FakeOrderRepository repoDengan(Order awal) {
    final repo = FakeOrderRepository(
      pemanggil: () => klienId,
      orderAwal: [awal],
    );
    addTearDown(repo.dispose);
    return repo;
  }

  test('permintaan tercatat pada ordernya', () async {
    final repo = repoDengan(order());

    await repo.mintaBatalOrder(orderId: 'o-uji', alasan: 'Acaranya batal.');

    expect((await repo.getOrder('o-uji'))!.mintaBatalPada, isNotNull);
  });

  /// Ordernya tetap berjalan sampai admin memutuskan. Permintaan yang langsung
  /// menghentikan pekerjaan berarti klien membatalkan sendiri lewat pintu belakang,
  /// persis yang tidak boleh terjadi karena di ujungnya ada uang.
  test('status ordernya tidak bergeser oleh permintaan', () async {
    final repo = repoDengan(order());

    await repo.mintaBatalOrder(orderId: 'o-uji', alasan: 'Acaranya batal.');

    expect((await repo.getOrder('o-uji'))!.status, OrderStatus.dikerjakan);
  });

  test('alasannya tertulis sebagai pesan dari klien di order itu', () async {
    final repo = repoDengan(order());

    await repo.mintaBatalOrder(
      orderId: 'o-uji',
      alasan: 'Acaranya batal, jadi tidak jadi dipakai.',
    );

    final pesan = (await repo.getOrder('o-uji'))!.messages.last;
    expect(pesan.isi, 'Acaranya batal, jadi tidak jadi dipakai.');
    expect(pesan.pengirim, MessageSender.klien);
  });

  test('alasan kosong ditolak', () async {
    final repo = repoDengan(order());

    await expectLater(
      repo.mintaBatalOrder(orderId: 'o-uji', alasan: '   '),
      throwsA(isA<StateError>()),
    );
  });

  /// Order yang belum dibayar bisa dibatalkan sendiri saat itu juga, jadi tidak ada
  /// yang perlu diminta ke admin.
  test('order yang belum dibayar tidak perlu lewat admin', () async {
    final repo = repoDengan(
      Order(
        id: 'o-uji',
        kodeOrder: 'SRH-9001',
        klienId: klienId,
        namaKlien: 'Dina Rahmawati',
        serviceType: ServiceType.anterJemput,
        status: OrderStatus.menungguPembayaran,
        dibuatPada: DateTime.now(),
        harga: 11000,
      ),
    );

    await expectLater(
      repo.mintaBatalOrder(orderId: 'o-uji', alasan: 'Acaranya batal.'),
      throwsA(isA<StateError>()),
    );
  });

  test('permintaan kedua ditolak selama yang pertama belum dijawab', () async {
    final repo = repoDengan(order());
    await repo.mintaBatalOrder(orderId: 'o-uji', alasan: 'Acaranya batal.');

    await expectLater(
      repo.mintaBatalOrder(orderId: 'o-uji', alasan: 'Sekali lagi.'),
      throwsA(isA<StateError>()),
    );
  });

  test('order yang sudah berakhir tidak bisa dimintakan pembatalan', () async {
    final repo = repoDengan(order(status: OrderStatus.selesai));

    await expectLater(
      repo.mintaBatalOrder(orderId: 'o-uji', alasan: 'Acaranya batal.'),
      throwsA(isA<StateError>()),
    );
  });
}
