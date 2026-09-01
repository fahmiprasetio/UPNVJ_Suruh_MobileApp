import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';

/// Tes alur penawaran Jalur B: tawar-menawar ala aplikasi ojek daring, bukan
/// satu penawaran tunggal dari admin.
///
/// Yang diuji aturannya, bukan tampilannya: harga yang ditawarkan belum jadi
/// harga order sampai klien menyetujui salah satunya, beberapa runner boleh
/// menawar bersamaan, menyetujui satu tawaran otomatis menutup tawaran lain,
/// dan menolak satu tawaran tidak mengakhiri ordernya. Ketiganya harus tetap
/// berlaku ketika repository sungguhan menggantikan yang tiruan, jadi tes ini
/// yang menentukan perilaku apa yang harus dihasilkan implementasi
/// berikutnya.
void main() {
  final jadwal = DateTime.now().add(const Duration(days: 2));
  const runnerSatu = 'u-runner-uji-1';
  const runnerDua = 'u-runner-uji-2';

  Order permintaan({
    OrderStatus status = OrderStatus.permintaan,
    ServiceType serviceType = ServiceType.bantuPindahKos,
    int? hargaUsulan = 150000,
  }) {
    return Order(
      id: 'o-uji',
      kodeOrder: 'SRH-9002',
      // Sama dengan SeedData.klien.id, karena pemanggil bawaan repo tiruan
      // memakainya sebagai klien: setuju/tolak/nego di tes ini memang
      // dipanggil sebagai klien, sementara menawar dipanggil eksplisit
      // sebagai runner lewat *Sebagai.
      klienId: 'u-klien-1',
      namaKlien: 'Dina Rahmawati',
      serviceType: serviceType,
      status: status,
      dibuatPada: DateTime.now(),
      deskripsi: 'Pindah kos, barang sekitar satu pikap.',
      jadwalMulai: jadwal,
      jumlahRunnerDibutuhkan: 3,
      hargaUsulan: hargaUsulan,
    );
  }

  Future<Order> penawaranDari(
    FakeOrderRepository repo,
    String runnerId, {
    int harga = 150000,
    DateTime? jadwalMulai,
    String? catatan,
  }) {
    return repo.buatPenawaranSebagai(
      orderId: 'o-uji',
      runnerId: runnerId,
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

    final order = await penawaranDari(repo, runnerSatu);

    expect(order.status, OrderStatus.permintaan);
    expect(order.harga, isNull);
    expect(order.penawaranPending, hasLength(1));
    expect(order.penawaranPending.single.harga, 150000);
    expect(order.penawaranPending.single.runnerId, runnerSatu);
  });

  test('dua runner berbeda boleh menawar bersamaan untuk order yang sama', () async {
    // Inti dari desain tawar-menawar ini: dua orang berbeda menawar order
    // yang sama pada saat yang sama bukan tabrakan.
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    await penawaranDari(repo, runnerSatu, harga: 150000);
    final order = await penawaranDari(repo, runnerDua, harga: 120000);

    expect(order.penawaranPending, hasLength(2));
    expect(
      order.penawaranMilikRunner(runnerSatu)?.harga,
      150000,
    );
    expect(order.penawaranMilikRunner(runnerDua)?.harga, 120000);
  });

  test('runner yang sama tidak bisa menawar dua kali selagi yang pertama menunggu', () async {
    // Beda dari dua runner berbeda menawar bersamaan (itu sah). Ini satu
    // runner mencoba menawar dua kali untuk order yang sama.
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    await penawaranDari(repo, runnerSatu, harga: 150000);

    expect(
      () => penawaranDari(repo, runnerSatu, harga: 90000),
      throwsStateError,
    );
  });

  test('klien tidak bisa menawar ordernya sendiri', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    expect(
      () => penawaranDari(repo, 'u-klien-1', harga: 1),
      throwsStateError,
    );
  });

  test('setuju memindahkan harga dan jadwal penawaran ke ordernya', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    final jadwalRunner = jadwal.add(const Duration(days: 1));
    final ditawar = await penawaranDari(
      repo,
      runnerSatu,
      harga: 175000,
      jadwalMulai: jadwalRunner,
    );
    final penawaranId = ditawar.penawaranPending.single.id;

    final order = await repo.setujuiPenawaran(
      orderId: 'o-uji',
      penawaranId: penawaranId,
    );

    expect(order.status, OrderStatus.menungguPembayaran);
    expect(order.harga, 175000);
    expect(order.estimasiDurasi, const Duration(hours: 2));
    // Jadwal yang berlaku adalah jadwal penawaran, bukan lagi yang diminta
    // klien: itu yang baru saja disetujui.
    expect(order.jadwalMulai, jadwalRunner);
    expect(
      order.offers.singleWhere((o) => o.id == penawaranId).status,
      OfferStatus.disetujui,
    );
    expect(order.penawaranPending, isEmpty);
  });

  test('menyetujui satu tawaran otomatis menutup tawaran runner lain', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    final ditawarSatu = await penawaranDari(repo, runnerSatu, harga: 150000);
    final penawaranSatu = ditawarSatu.penawaranPending.single.id;
    await penawaranDari(repo, runnerDua, harga: 120000);

    final order = await repo.setujuiPenawaran(
      orderId: 'o-uji',
      penawaranId: penawaranSatu,
    );

    expect(
      order.offers.singleWhere((o) => o.id == penawaranSatu).status,
      OfferStatus.disetujui,
    );
    expect(
      order.offers.singleWhere((o) => o.id != penawaranSatu).status,
      OfferStatus.ditutup,
    );
  });

  test('menolak satu tawaran tidak mengakhiri ordernya', () async {
    // Beda dari alur admin lama: menolak satu tawaran tidak lagi
    // membatalkan ordernya.
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    final ditawar = await penawaranDari(repo, runnerSatu);
    final penawaranId = ditawar.penawaranPending.single.id;

    final order = await repo.tolakPenawaran(
      orderId: 'o-uji',
      penawaranId: penawaranId,
    );

    expect(order.status, OrderStatus.permintaan);
    expect(order.harga, isNull);
    expect(
      order.offers.singleWhere((o) => o.id == penawaranId).status,
      OfferStatus.ditolak,
    );
  });

  test('setelah ditolak, runner lain masih bisa menawar order itu', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    final ditawar = await penawaranDari(repo, runnerSatu);
    final penawaranId = ditawar.penawaranPending.single.id;
    await repo.tolakPenawaran(orderId: 'o-uji', penawaranId: penawaranId);

    final order = await penawaranDari(repo, runnerDua, harga: 130000);

    expect(order.penawaranMilikRunner(runnerDua)?.status, OfferStatus.pending);
  });

  test('nego menulis alasannya di jalur obrolan pribadi runner itu', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    final ditawar = await penawaranDari(repo, runnerSatu);
    final penawaranId = ditawar.penawaranPending.single.id;

    final order = await repo.ajukanNego(
      orderId: 'o-uji',
      penawaranId: penawaranId,
      alasan: 'Barangnya ternyata cuma 2 koper, tidak sampai satu pikap.',
    );

    expect(order.status, OrderStatus.permintaan);
    expect(
      order.offers.singleWhere((o) => o.id == penawaranId).status,
      OfferStatus.dinegoUlang,
    );
    expect(order.messages, hasLength(1));
    expect(order.messages.single.pengirim, MessageSender.klien);
    expect(order.messages.single.runnerId, runnerSatu);
    expect(order.messages.single.isi, contains('2 koper'));
  });

  test('nego tanpa alasan ditolak', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    final ditawar = await penawaranDari(repo, runnerSatu);
    final penawaranId = ditawar.penawaranPending.single.id;

    expect(
      () => repo.ajukanNego(
        orderId: 'o-uji',
        penawaranId: penawaranId,
        alasan: '   ',
      ),
      throwsStateError,
    );
  });

  test('runner yang sama bisa menawar lagi setelah dinego', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    final ditawar = await penawaranDari(repo, runnerSatu, harga: 150000);
    final penawaranId = ditawar.penawaranPending.single.id;
    await repo.ajukanNego(
      orderId: 'o-uji',
      penawaranId: penawaranId,
      alasan: 'Barangnya lebih sedikit.',
    );
    final order = await penawaranDari(repo, runnerSatu, harga: 110000);

    expect(order.status, OrderStatus.permintaan);
    expect(order.offers, hasLength(2));
    expect(order.penawaranPending.single.harga, 110000);
  });

  test('order Jalur A tidak bisa ditawari harga baru', () async {
    // Harga Jalur A dihitung dari isian form dan sudah tampil di layar klien
    // sejak awal. Membuka penawaran di sana berarti membuka jalan mengubah
    // harga yang sudah disepakati.
    final repo = FakeOrderRepository(
      orderAwal: [permintaan(serviceType: ServiceType.anterJemput)],
    );
    addTearDown(repo.dispose);

    expect(() => penawaranDari(repo, runnerSatu), throwsStateError);
  });

  test('setuju terhadap penawaran yang tidak ada ditolak', () async {
    // Tombolnya memang disembunyikan layar, tapi yang menghentikan panggilan
    // langsung adalah pemeriksaan di sini.
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    expect(
      () => repo.setujuiPenawaran(orderId: 'o-uji', penawaranId: 'tidak-ada'),
      throwsStateError,
    );
  });

  test('penawaran yang sudah dijawab tidak bisa dijawab dua kali', () async {
    final repo = FakeOrderRepository(orderAwal: [permintaan()]);
    addTearDown(repo.dispose);

    final ditawar = await penawaranDari(repo, runnerSatu);
    final penawaranId = ditawar.penawaranPending.single.id;
    await repo.setujuiPenawaran(orderId: 'o-uji', penawaranId: penawaranId);

    expect(
      () => repo.tolakPenawaran(orderId: 'o-uji', penawaranId: penawaranId),
      throwsStateError,
    );
  });
}
