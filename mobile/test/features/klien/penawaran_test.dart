import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';

import '../../support/tiruan.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/domain/models/order_offer.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

/// Tes sisi klien untuk tawaran runner Jalur B: tawar-menawar ala aplikasi
/// ojek daring, bukan satu penawaran tunggal dari admin.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding
        .ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding
        .ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  final jadwalDiminta = DateTime(2026, 9, 5, 9);
  const runnerId = 'u-runner-uji';

  Order orderDenganPenawaran({
    DateTime? jadwalPenawaran,
    String? catatan,
    OfferStatus status = OfferStatus.pending,
  }) {
    return Order(
      id: 'o-uji',
      kodeOrder: 'SRH-9004',
      klienId: SeedData.klien.id,
      namaKlien: SeedData.klien.nama,
      serviceType: ServiceType.bantuPindahKos,
      // Order Jalur B tetap Permintaan selama masih menerima tawaran, tidak
      // peduli sudah ada berapa tawaran yang menunggu di dalamnya.
      status: OrderStatus.permintaan,
      dibuatPada: DateTime.now().subtract(const Duration(hours: 1)),
      deskripsi: 'Pindah kos, barang sekitar satu pikap.',
      alamatTujuan: 'Kos Anggrek, Jl. RS Fatmawati',
      jadwalMulai: jadwalDiminta,
      jumlahRunnerDibutuhkan: 3,
      hargaUsulan: 160000,
      offers: [
        OrderOffer(
          id: 'p-uji',
          orderId: 'o-uji',
          runnerId: runnerId,
          namaRunner: 'Runner Uji',
          harga: 175000,
          estimasiDurasi: const Duration(hours: 2),
          jadwalMulai: jadwalPenawaran ?? jadwalDiminta,
          dibuatPada: DateTime.now().subtract(const Duration(minutes: 10)),
          status: status,
          catatan: catatan,
        ),
      ],
    );
  }

  /// Membaca keadaan order tanpa memanggil metode yang berjeda.
  ///
  /// Di dalam widget test, waktu hanya berjalan ketika tester memompanya.
  /// Memanggil metode repository yang memakai jeda jaringan palsu di luar
  /// pompa itu membuat tesnya menggantung selamanya, jadi keadaannya dibaca
  /// lewat stream yang memancarkan snapshot langsung.
  Future<Order> bacaOrder(FakeOrderRepository repo) async {
    return (await repo.watchOrder('o-uji').first)!;
  }

  Future<FakeOrderRepository> bukaDetail(
    WidgetTester tester,
    Order order,
  ) async {
    final repo = FakeOrderRepository(orderAwal: [order]);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          orderRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pesanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(order.kodeOrder));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('tawaran menyebut harga, jadwal, dan lamanya', (tester) async {
    // Klien tidak bisa menyetujui apa yang tidak ia lihat. Ketiga angka ini
    // harus ada sebelum tombol setuju berarti apa-apa.
    await bukaDetail(tester, orderDenganPenawaran());

    expect(find.text('Tawaran runner'), findsOneWidget);
    expect(find.text('Rp 175.000'), findsOneWidget);
    expect(find.textContaining('Sabtu, 5 September 2026'), findsWidgets);
    expect(find.text('2 jam'), findsOneWidget);
  });

  testWidgets('tawaran yang sama dengan harga usulan diberi label khusus', (
    tester,
  ) async {
    await bukaDetail(
      tester,
      orderDenganPenawaran().copyWith(hargaUsulan: 175000),
    );

    expect(find.text('Runner menyanggupi harga usulanmu'), findsOneWidget);
  });

  testWidgets('tiga jalan keluar tersedia sekaligus', (tester) async {
    // Nego yang disembunyikan membuat klien menekan tolak, dan tawaran yang
    // sebenarnya masih bisa jadi hilang begitu saja.
    await bukaDetail(tester, orderDenganPenawaran());

    expect(find.text('Setuju & Bayar'), findsOneWidget);
    expect(find.text('Minta Ditinjau Ulang'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
  });

  testWidgets('jadwal yang digeser runner diberitahukan, bukan dibiarkan', (
    tester,
  ) async {
    await bukaDetail(
      tester,
      orderDenganPenawaran(jadwalPenawaran: DateTime(2026, 9, 6, 13)),
    );

    expect(find.textContaining('Minggu, 6 September 2026'), findsWidgets);
    expect(
      find.textContaining('mengusulkan waktu lain dari yang kamu minta'),
      findsOneWidget,
    );
  });

  testWidgets('setuju mengantar klien ke pembayaran dengan harga tawaran', (
    tester,
  ) async {
    final repo = await bukaDetail(tester, orderDenganPenawaran());

    await tester.tap(find.text('Setuju & Bayar'));
    await tester.pumpAndSettle();

    expect(find.text('Pembayaran'), findsOneWidget);

    final order = await bacaOrder(repo);
    expect(order.status, OrderStatus.menungguPembayaran);
    expect(order.harga, 175000);
  });

  testWidgets('nego mengirim alasannya ke jalur obrolan pribadi runner itu', (
    tester,
  ) async {
    final repo = await bukaDetail(tester, orderDenganPenawaran());

    await tester.tap(find.text('Minta Ditinjau Ulang'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'Barangnya cuma 2 koper, tidak sampai satu pikap.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    final order = await bacaOrder(repo);
    expect(order.status, OrderStatus.permintaan);
    expect(order.messages.single.isi, contains('2 koper'));
    expect(order.messages.single.pengirim, MessageSender.klien);
    expect(order.messages.single.runnerId, runnerId);
  });

  testWidgets('nego tanpa alasan tidak bisa dikirim', (tester) async {
    await bukaDetail(tester, orderDenganPenawaran());

    await tester.tap(find.text('Minta Ditinjau Ulang'));
    await tester.pumpAndSettle();

    final kirim = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Kirim'),
    );
    expect(kirim.onPressed, isNull);
  });

  testWidgets('tolak meminta kepastian, dan cuma menutup tawaran itu', (
    tester,
  ) async {
    // Beda dari alur admin lama: menolak satu tawaran tidak lagi
    // membatalkan ordernya.
    final repo = await bukaDetail(tester, orderDenganPenawaran());

    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();

    expect(find.text('Tolak tawaran ini?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect((await bacaOrder(repo)).status, OrderStatus.permintaan);

    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tolak Tawaran'));
    await tester.pumpAndSettle();

    final order = await bacaOrder(repo);
    expect(order.status, OrderStatus.permintaan);
    expect(order.offers.single.status, OfferStatus.ditolak);
  });

  testWidgets('permintaan yang belum ditawari tidak memajang angka apa pun', (
    tester,
  ) async {
    // Aturan yang sama dengan form Jalur B: tidak ada harga sebelum ada yang
    // disetujui.
    final tanpaPenawaran = orderDenganPenawaran().copyWith(
      status: OrderStatus.permintaan,
      offers: const [],
    );
    await bukaDetail(tester, tanpaPenawaran);

    // Harga yang belum ada ditulis sebesar harga sungguhan di kepala layar,
    // bukan diringkas jadi baris terakhir di tabel rincian.
    expect(find.text('Harga menunggu penawaran'), findsOneWidget);
    expect(find.text('Tawaran runner'), findsNothing);
    expect(find.text('Rp 175.000'), findsNothing);
    expect(find.text('Setuju & Bayar'), findsNothing);
  });

  testWidgets('beberapa tawaran dari runner berbeda tampil sekaligus', (
    tester,
  ) async {
    final duaPenawaran = orderDenganPenawaran().copyWith(
      offers: [
        OrderOffer(
          id: 'p-satu',
          orderId: 'o-uji',
          runnerId: 'u-runner-satu',
          namaRunner: 'Runner Satu',
          harga: 175000,
          estimasiDurasi: const Duration(hours: 2),
          jadwalMulai: jadwalDiminta,
          dibuatPada: DateTime.now(),
          status: OfferStatus.pending,
        ),
        OrderOffer(
          id: 'p-dua',
          orderId: 'o-uji',
          runnerId: 'u-runner-dua',
          namaRunner: 'Runner Dua',
          harga: 150000,
          estimasiDurasi: const Duration(hours: 3),
          jadwalMulai: jadwalDiminta,
          dibuatPada: DateTime.now(),
          status: OfferStatus.pending,
        ),
      ],
    );
    await bukaDetail(tester, duaPenawaran);

    expect(find.text('Rp 175.000'), findsOneWidget);
    expect(find.text('Rp 150.000'), findsOneWidget);
    expect(find.text('Setuju & Bayar'), findsNWidgets(2));

    // Klien tidak boleh memilih cuma dari harga tanpa tahu siapa runnernya.
    expect(find.text('Runner Satu'), findsOneWidget);
    expect(find.text('Runner Dua'), findsOneWidget);
  });
}
