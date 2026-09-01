import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/core/config/batas_masukan.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/domain/models/order_offer.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';

/// Teks bebas yang tidak dibatasi adalah pintu membebani penyimpanan, dan
/// batas yang cuma dipasang di layar bukan batas: kolom bisa diisi lewat
/// tempel, dan nanti lewat pemanggilan API langsung.
void main() {
  String panjang(int n) => 'a' * n;

  Order orderAktif() => Order(
    id: 'o-uji',
    kodeOrder: 'SRH-9001',
    klienId: 'u-klien-1',
    namaKlien: 'Dina Rahmawati',
    serviceType: ServiceType.anterJemput,
    status: OrderStatus.mencariRunner,
    dibuatPada: DateTime.now(),
    harga: 11000,
  );

  test('pesan chat yang melewati batas ditolak', () async {
    final repo = FakeOrderRepository(orderAwal: [orderAktif()]);
    addTearDown(repo.dispose);

    await expectLater(
      repo.kirimPesanSebagai(
        orderId: 'o-uji',
        pengirimId: SeedData.klien.id,
        isi: panjang(BatasMasukan.pesanChat + 1),
      ),
      throwsStateError,
    );
  });

  test('pesan chat tepat di batas tetap diterima', () async {
    final repo = FakeOrderRepository(orderAwal: [orderAktif()]);
    addTearDown(repo.dispose);

    final order = await repo.kirimPesanSebagai(
      orderId: 'o-uji',
      pengirimId: SeedData.klien.id,
      isi: panjang(BatasMasukan.pesanChat),
    );

    expect(order.messages, hasLength(1));
  });

  test('deskripsi dan alamat order Jalur A dibatasi', () async {
    final repo = FakeOrderRepository(orderAwal: const []);
    addTearDown(repo.dispose);

    await expectLater(
      repo.buatOrderJalurA(
        serviceType: ServiceType.anterJemput,
        jarakKm: 3,
        deskripsi: panjang(BatasMasukan.deskripsi + 1),
      ),
      throwsStateError,
    );

    await expectLater(
      repo.buatOrderJalurA(
        serviceType: ServiceType.anterJemput,
        jarakKm: 3,
        alamatJemput: panjang(BatasMasukan.alamat + 1),
      ),
      throwsStateError,
    );
  });

  test('deskripsi permintaan Jalur B dibatasi', () async {
    final repo = FakeOrderRepository(orderAwal: const []);
    addTearDown(repo.dispose);

    await expectLater(
      repo.buatPermintaanJalurB(
        serviceType: ServiceType.bersihKos,
        deskripsi: panjang(BatasMasukan.deskripsi + 1),
        jadwalMulai: DateTime.now().add(const Duration(days: 1)),
        hargaUsulan: 150000,
      ),
      throwsStateError,
    );
  });

  test('alasan nego yang melewati batas ditolak', () async {
    final order = orderAktif().copyWith(
      status: OrderStatus.permintaan,
      offers: [
        OrderOffer(
          id: 'p-1',
          orderId: 'o-uji',
          runnerId: 'u-runner-1',
          harga: 50000,
          estimasiDurasi: const Duration(hours: 2),
          jadwalMulai: DateTime.now().add(const Duration(days: 1)),
          dibuatPada: DateTime.now(),
          status: OfferStatus.pending,
        ),
      ],
    );
    final repo = FakeOrderRepository(orderAwal: [order]);
    addTearDown(repo.dispose);

    await expectLater(
      repo.ajukanNego(
        orderId: 'o-uji',
        penawaranId: 'p-1',
        alasan: panjang(BatasMasukan.alasanNego + 1),
      ),
      throwsStateError,
    );
  });

  test('catatan serah terima yang melewati batas ditolak', () async {
    final order = orderAktif().copyWith(
      status: OrderStatus.dikerjakan,
      runnerIds: const ['u-runner-1'],
    );
    final repo = FakeOrderRepository(orderAwal: [order]);
    addTearDown(repo.dispose);

    await expectLater(
      repo.selesaikanOrderSebagai(
        orderId: 'o-uji',
        runnerId: 'u-runner-1',
        fotoBuktiUrl: 'fake://bukti/o-uji.jpg',
        catatanSerahTerima: panjang(BatasMasukan.catatanSerahTerima + 1),
      ),
      throwsStateError,
    );
  });
}
