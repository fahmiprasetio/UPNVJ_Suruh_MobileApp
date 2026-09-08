import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/domain/models/runner_ringkas.dart';

/// Runner mundur dari order yang sudah dipegangnya.
///
/// Sebelum ini tidak ada jalan keluar sama sekali: ordernya menggantung sampai
/// runner memaksa menandainya selesai, atau admin membatalkan seluruhnya berikut
/// pengembalian dana, padahal yang dibutuhkan klien cuma runner lain.
///
/// Diuji di sini, bukan lewat layarnya, karena yang diperiksa keadaan tersimpannya:
/// jam di dalam tes widget tidak maju sendiri, jadi menunggu aliran repository di
/// sana menggantung sampai batas waktu tanpa membuktikan apa pun. Layarnya diuji
/// terpisah, dan yang dijaga di sana memang hal yang berbeda: tombolnya muncul untuk
/// order yang benar, dan menuntut alasan sebelum bisa ditekan.
void main() {
  const runnerId = 'u-runner-1';

  Order orderDipegang({
    OrderStatus status = OrderStatus.dikerjakan,
    int jumlahRunnerDibutuhkan = 1,
    List<String> runnerIds = const [runnerId],
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
      runners: [for (final id in runnerIds) RunnerRingkas(id: id, nama: 'Runner')],
    );
  }

  FakeOrderRepository repoDengan(Order order) {
    final repo = FakeOrderRepository(
      pemanggil: () => runnerId,
      orderAwal: [order],
    );
    addTearDown(repo.dispose);
    return repo;
  }

  test('order yang dilepas kembali dicari runner', () async {
    final repo = repoDengan(orderDipegang());

    await repo.lepasOrder(orderId: 'o-uji', alasan: 'Motor mogok.');

    final sesudah = (await repo.getOrder('o-uji'))!;
    expect(sesudah.status, OrderStatus.mencariRunner);
    expect(sesudah.runnerIds, isEmpty);
  });

  /// Klien yang melihat ordernya mundur sendiri dari "dikerjakan" jadi "mencari
  /// runner" tanpa satu kalimat pun akan menyimpulkan sistemnya rusak. Alasannya
  /// sampai lewat percakapan yang sudah dibuka kedua belah pihak, bukan lewat kolom
  /// baru yang butuh layar baru untuk terlihat.
  test('alasannya tertulis sebagai pesan dari runner di order itu', () async {
    final repo = repoDengan(orderDipegang());

    await repo.lepasOrder(orderId: 'o-uji', alasan: 'Maaf, motor saya mogok.');

    final pesan = (await repo.getOrder('o-uji'))!.messages.last;
    expect(pesan.isi, 'Maaf, motor saya mogok.');
    expect(pesan.pengirim, MessageSender.runner);
  });

  test('alasan kosong ditolak', () async {
    final repo = repoDengan(orderDipegang());

    await expectLater(
      repo.lepasOrder(orderId: 'o-uji', alasan: '   '),
      throwsA(isA<StateError>()),
    );
  });

  test('runner yang tidak memegang order itu tidak bisa melepasnya', () async {
    final repo = repoDengan(orderDipegang(runnerIds: const ['u-runner-lain']));

    await expectLater(
      repo.lepasOrder(orderId: 'o-uji', alasan: 'Motor mogok.'),
      throwsA(isA<StateError>()),
    );
  });

  /// Mengembalikan order yang sudah diserahkan ke mencari runner berarti pekerjaan
  /// yang sudah dibayar dan sudah selesai disiarkan ulang untuk dikerjakan kedua
  /// kalinya.
  test('order yang sudah selesai tidak bisa dilepas', () async {
    final repo = repoDengan(orderDipegang(status: OrderStatus.selesai));

    await expectLater(
      repo.lepasOrder(orderId: 'o-uji', alasan: 'Motor mogok.'),
      throwsA(isA<StateError>()),
    );
  });

  /// Slot yang baru kosong harus benar-benar terbuka lagi, dan runner lain yang
  /// masih memegang ordernya tidak boleh ikut terlepas.
  test('pada order dua runner, yang tersisa tetap memegangnya', () async {
    final repo = repoDengan(
      orderDipegang(
        jumlahRunnerDibutuhkan: 2,
        runnerIds: const [runnerId, 'u-runner-2'],
      ),
    );

    await repo.lepasOrder(orderId: 'o-uji', alasan: 'Motor mogok.');

    final sesudah = (await repo.getOrder('o-uji'))!;
    expect(sesudah.status, OrderStatus.mencariRunner);
    expect(sesudah.runnerIds, ['u-runner-2']);
  });
}
