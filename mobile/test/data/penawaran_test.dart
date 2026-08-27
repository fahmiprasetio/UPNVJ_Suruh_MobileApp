import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';

/// Tes alur penawaran Jalur B (rencana capstone bagian 3).
///
/// Yang diuji aturannya, bukan tampilannya: harga yang baru ditawarkan belum
/// jadi harga order, penolakan menutup order, dan nego mengembalikannya ke
/// antrean admin. Ketiganya harus tetap berlaku ketika repository sungguhan
/// menggantikan yang tiruan, jadi tes ini yang menentukan perilaku apa yang
/// harus dihasilkan implementasi berikutnya.
void main() {
  final jadwal = DateTime.now().add(const Duration(days: 2));

  Order permintaan({
    OrderStatus status = OrderStatus.permintaan,
    ServiceType serviceType = ServiceType.bantuPindahKos,
  }) {
    return Order(
      id: 'o-uji',
      kodeOrder: 'SRH-9002',
      klienId: 'u-klien-1',
      namaKlien: 'Dina Rahmawati',
      serviceType: serviceType,
      status: status,
      dibuatPada: DateTime.now(),
      deskripsi: 'Pindah kos, barang sekitar satu pikap.',
      jadwalMulai: jadwal,
      jumlahRunnerDibutuhkan: 3,
    );
  }

  Future<Order> denganPenawaran(
    FakeOrderRepository repo, {
    int harga = 150000,
    DateTime? jadwalMulai,
    String? catatan,
  }) {
    return repo.buatPenawaran(
      orderId: 'o-uji',
      harga: harga,
      estimasiDurasi: const Duration(hours: 2),
      jadwalMulai: jadwalMulai ?? jadwal,
      catatan: catatan,
    );
  }

  test('penawaran yang menunggu jawaban belum jadi harga order', () async {
    // Aturan terpenting di alur ini. Order yang memajang harga sebelum klien
    // setuju akan terbaca sebagai tagihan, padahal itu baru usulan.
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    final order = await denganPenawaran(repo);

    expect(order.status, OrderStatus.menungguPersetujuanKlien);
    expect(order.harga, isNull);
    expect(order.penawaranMenunggu, isNotNull);
    expect(order.penawaranMenunggu!.harga, 150000);
  });

  test('setuju memindahkan harga dan jadwal penawaran ke ordernya', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    final jadwalAdmin = jadwal.add(const Duration(days: 1));
    await denganPenawaran(repo, harga: 175000, jadwalMulai: jadwalAdmin);
    final order = await repo.setujuiPenawaran('o-uji');

    expect(order.status, OrderStatus.menungguPembayaran);
    expect(order.harga, 175000);
    expect(order.estimasiDurasi, const Duration(hours: 2));
    // Jadwal yang berlaku adalah jadwal penawaran, bukan lagi yang diminta
    // klien: itu yang baru saja disetujui.
    expect(order.jadwalMulai, jadwalAdmin);
    expect(order.penawaranTerakhir!.status, OfferStatus.disetujui);
    expect(order.penawaranMenunggu, isNull);
  });

  test('tolak menutup ordernya, bukan mengembalikannya ke admin', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    await denganPenawaran(repo);
    final order = await repo.tolakPenawaran('o-uji');

    expect(order.status, OrderStatus.batal);
    expect(order.harga, isNull);
    expect(order.penawaranTerakhir!.status, OfferStatus.ditolak);
  });

  test('nego mengembalikan order ke antrean admin, alasannya masuk chat', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    await denganPenawaran(repo);
    final order = await repo.ajukanNego(
      orderId: 'o-uji',
      alasan: 'Barangnya ternyata cuma 2 koper, tidak sampai satu pikap.',
    );

    expect(order.status, OrderStatus.permintaan);
    expect(order.penawaranTerakhir!.status, OfferStatus.dinegoUlang);
    expect(order.messages, hasLength(1));
    expect(order.messages.single.pengirim, MessageSender.klien);
    expect(order.messages.single.isi, contains('2 koper'));
  });

  test('nego tanpa alasan ditolak', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    await denganPenawaran(repo);

    expect(
      () => repo.ajukanNego(orderId: 'o-uji', alasan: '   '),
      throwsStateError,
    );
  });

  test('order yang sudah dinego bisa ditawari lagi', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    await denganPenawaran(repo, harga: 150000);
    await repo.ajukanNego(orderId: 'o-uji', alasan: 'Barangnya lebih sedikit.');
    final order = await denganPenawaran(repo, harga: 110000);

    expect(order.status, OrderStatus.menungguPersetujuanKlien);
    expect(order.offers, hasLength(2));
    expect(order.penawaranMenunggu!.harga, 110000);
  });

  test('penawaran kedua tidak boleh menimpa penawaran yang sedang dibaca', () async {
    // Kalau ini diizinkan, klien menekan setuju untuk harga yang berbeda dari
    // yang tampil di layarnya.
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    await denganPenawaran(repo, harga: 150000);

    expect(() => denganPenawaran(repo, harga: 90000), throwsStateError);
  });

  test('order Jalur A tidak bisa ditawari harga baru', () async {
    // Harga Jalur A dihitung dari isian form dan sudah tampil di layar klien
    // sejak awal. Membuka penawaran di sana berarti membuka jalan mengubah
    // harga yang sudah disepakati.
    final repo = FakeOrderRepository(
      orderAwal: [permintaan(serviceType: ServiceType.anterJemput)],
    );
    addTearDown(repo.dispose);

    expect(() => denganPenawaran(repo), throwsStateError);
  });

  test('setuju tanpa penawaran yang menunggu ditolak', () async {
    // Tombolnya memang disembunyikan layar, tapi yang menghentikan panggilan
    // langsung adalah pemeriksaan di sini.
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    expect(() => repo.setujuiPenawaran('o-uji'), throwsStateError);
  });

  test('penawaran yang sudah dijawab tidak bisa dijawab dua kali', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    await denganPenawaran(repo);
    await repo.setujuiPenawaran('o-uji');

    expect(() => repo.tolakPenawaran('o-uji'), throwsStateError);
  });
}
