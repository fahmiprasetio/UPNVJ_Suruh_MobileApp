import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/domain/models/order_offer.dart';

/// Runner menarik kembali penawarannya sendiri.
///
/// Diuji di sini, bukan lewat layar, dengan alasan yang sama seperti
/// `lepas_order_test.dart` dan `minta_batal_test.dart`: yang diperiksa keadaan
/// tersimpannya, dan jam di dalam tes widget tidak maju sendiri, jadi menunggu aliran
/// repository di sana menggantung sampai batas waktu tanpa membuktikan apa pun.
void main() {
  const runnerId = 'u-runner-1';

  Order permintaan({OfferStatus status = OfferStatus.pending}) {
    final sekarang = DateTime.now();

    return Order(
      id: 'o-uji',
      kodeOrder: 'SRH-9101',
      klienId: 'u-klien-1',
      namaKlien: 'Dina Rahmawati',
      serviceType: ServiceType.bersihKos,
      status: OrderStatus.permintaan,
      dibuatPada: sekarang,
      hargaUsulan: 150000,
      offers: [
        OrderOffer(
          id: 'f-1',
          orderId: 'o-uji',
          runnerId: runnerId,
          namaRunner: 'Runner Uji',
          harga: 50000,
          estimasiDurasi: const Duration(hours: 3),
          jadwalMulai: sekarang.add(const Duration(days: 2)),
          dibuatPada: sekarang,
          status: status,
        ),
      ],
    );
  }

  FakeOrderRepository repoDengan(Order awal) {
    final repo = FakeOrderRepository(
      pemanggil: () => runnerId,
      orderAwal: [awal],
    );
    addTearDown(repo.dispose);
    return repo;
  }

  /// Statusnya berubah, barisnya tidak hilang: klien yang sempat melihat tawaran itu
  /// berhak tahu bedanya "runner menariknya kembali" dari "tawaran itu tidak pernah ada".
  test('tawaran yang ditarik berubah statusnya, bukan hilang', () async {
    final repo = repoDengan(permintaan());

    await repo.cabutPenawaran(orderId: 'o-uji', penawaranId: 'f-1');

    final sesudah = (await repo.getOrder('o-uji'))!;
    expect(sesudah.offers.single.status, OfferStatus.dicabut);
  });

  test('alasan yang ditulis tersimpan sebagai pesan dari runner', () async {
    final repo = repoDengan(permintaan());

    await repo.cabutPenawaran(
      orderId: 'o-uji',
      penawaranId: 'f-1',
      alasan: 'Maaf, saya salah ketik harganya.',
    );

    final pesan = (await repo.getOrder('o-uji'))!.messages.last;
    expect(pesan.isi, 'Maaf, saya salah ketik harganya.');
    expect(pesan.pengirim, MessageSender.runner);
  });

  /// Alasan yang paling sering sebenarnya cuma "salah ketik", jadi mewajibkannya cuma
  /// memaksa orang mengetik itu. Yang ditarik pun tawaran yang belum diterima siapa pun.
  test('menarik tanpa alasan tidak menambah pesan apa pun', () async {
    final repo = repoDengan(permintaan());

    await repo.cabutPenawaran(orderId: 'o-uji', penawaranId: 'f-1');

    expect((await repo.getOrder('o-uji'))!.messages, isEmpty);
  });

  test('tawaran yang diminta dihitung ulang masih bisa ditarik', () async {
    final repo = repoDengan(permintaan(status: OfferStatus.dinegoUlang));

    await repo.cabutPenawaran(orderId: 'o-uji', penawaranId: 'f-1');

    expect((await repo.getOrder('o-uji'))!.offers.single.status, OfferStatus.dicabut);
  });

  /// Harga ordernya sudah ditetapkan dari tawaran ini dan klien mungkin sedang
  /// membayarnya; menariknya di titik itu meninggalkan klien membayar pekerjaan yang
  /// tidak lagi punya siapa-siapa.
  test('tawaran yang sudah disetujui tidak bisa ditarik', () async {
    final repo = repoDengan(permintaan(status: OfferStatus.disetujui));

    await expectLater(
      repo.cabutPenawaran(orderId: 'o-uji', penawaranId: 'f-1'),
      throwsA(isA<StateError>()),
    );
  });

  test('tawaran milik runner lain tidak bisa ditarik', () async {
    final repo = FakeOrderRepository(
      pemanggil: () => 'u-runner-lain',
      orderAwal: [permintaan()],
    );
    addTearDown(repo.dispose);

    await expectLater(
      repo.cabutPenawaran(orderId: 'o-uji', penawaranId: 'f-1'),
      throwsA(isA<StateError>()),
    );
  });

  /// Inti kenapa endpoint ini ada. Selama tawaran lama masih menunggu, penggantinya
  /// ditolak; menariknya lebih dulu yang membuka jalan mengirim angka yang benar.
  test('sesudah ditarik, order itu muncul lagi di daftar order masuk runner', () async {
    final repo = repoDengan(permintaan());
    expect(
      (await repo.watchOrderTersiarUntuk(runnerId).first).isi,
      isEmpty,
    );

    await repo.cabutPenawaran(orderId: 'o-uji', penawaranId: 'f-1');

    expect(
      (await repo.watchOrderTersiarUntuk(runnerId).first).isi.single.id,
      'o-uji',
    );
  });

  test('tawaran yang masih hidup muncul di daftar tawaran runner', () async {
    final repo = repoDengan(permintaan());

    expect((await repo.watchTawaranUntuk(runnerId).first).isi.single.id, 'o-uji');

    await repo.cabutPenawaran(orderId: 'o-uji', penawaranId: 'f-1');

    expect((await repo.watchTawaranUntuk(runnerId).first).isi, isEmpty);
  });
}
