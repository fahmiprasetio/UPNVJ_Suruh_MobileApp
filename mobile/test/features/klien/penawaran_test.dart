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

/// Tes sisi klien untuk penawaran admin (rencana capstone bagian 3).
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
      status: status == OfferStatus.pending
          ? OrderStatus.menungguPersetujuanKlien
          : OrderStatus.permintaan,
      dibuatPada: DateTime.now().subtract(const Duration(hours: 1)),
      deskripsi: 'Pindah kos, barang sekitar satu pikap.',
      alamatTujuan: 'Kos Anggrek, Jl. RS Fatmawati',
      jadwalMulai: jadwalDiminta,
      jumlahRunnerDibutuhkan: 3,
      offers: [
        OrderOffer(
          id: 'p-uji',
          orderId: 'o-uji',
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

    await tester.tap(find.byTooltip('Order Saya'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(order.kodeOrder));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('penawaran menyebut harga, jadwal, dan lamanya', (tester) async {
    // Klien tidak bisa menyetujui apa yang tidak ia lihat. Ketiga angka ini
    // harus ada sebelum tombol setuju berarti apa-apa.
    await bukaDetail(tester, orderDenganPenawaran());

    expect(find.text('Penawaran admin'), findsOneWidget);
    expect(find.text('Rp 175.000'), findsOneWidget);
    expect(find.textContaining('Sabtu, 5 September 2026'), findsWidgets);
    expect(find.text('2 jam'), findsOneWidget);
  });

  testWidgets('tiga jalan keluar tersedia sekaligus', (tester) async {
    // Nego yang disembunyikan membuat klien menekan tolak, dan order yang
    // sebenarnya masih bisa jadi hilang begitu saja.
    await bukaDetail(tester, orderDenganPenawaran());

    expect(find.text('Setuju & Bayar'), findsOneWidget);
    expect(find.text('Minta Ditinjau Ulang'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
  });

  testWidgets('jadwal yang digeser admin diberitahukan, bukan dibiarkan', (
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

  testWidgets('setuju mengantar klien ke pembayaran dengan harga penawaran', (
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

  testWidgets('nego mengirim alasannya ke chat order', (tester) async {
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

  testWidgets('tolak meminta kepastian dulu sebelum membatalkan order', (
    tester,
  ) async {
    final repo = await bukaDetail(tester, orderDenganPenawaran());

    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();

    expect(find.text('Tolak penawaran ini?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(
      (await bacaOrder(repo)).status,
      OrderStatus.menungguPersetujuanKlien,
    );

    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tolak & Batalkan'));
    await tester.pumpAndSettle();

    expect((await bacaOrder(repo)).status, OrderStatus.batal);
  });

  testWidgets('permintaan yang belum ditawari tidak memajang angka apa pun', (
    tester,
  ) async {
    // Aturan yang sama dengan form Jalur B (bagian 20.2): tidak ada harga
    // sebelum ada yang menyetujuinya.
    final tanpaPenawaran = orderDenganPenawaran().copyWith(
      status: OrderStatus.permintaan,
      offers: const [],
    );
    await bukaDetail(tester, tanpaPenawaran);

    // Harga yang belum ada ditulis sebesar harga sungguhan di kepala layar,
    // bukan diringkas jadi baris terakhir di tabel rincian.
    expect(find.text('Harga menunggu penawaran'), findsOneWidget);
    expect(find.text('Penawaran admin'), findsNothing);
    expect(find.text('Rp 175.000'), findsNothing);
    expect(find.text('Setuju & Bayar'), findsNothing);
  });

  testWidgets('panel alat penguji berdiri di tempat dashboard admin', (
    tester,
  ) async {
    // Admin bekerja di dashboard web (bagian 14.2), jadi bagi aplikasi ini
    // penawaran datang dari luar. Panel ini yang menggantikannya sekarang, dan
    // ia harus mengaku sebagai alat penguji, bukan menyamar jadi fitur.
    final tanpaPenawaran = orderDenganPenawaran().copyWith(
      status: OrderStatus.permintaan,
      offers: const [],
    );
    final repo = await bukaDetail(tester, tanpaPenawaran);

    expect(find.text('ALAT PENGUJI'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '200000');
    await tester.tap(find.text('Simulasikan penawaran admin'));
    await tester.pumpAndSettle();

    final order = await bacaOrder(repo);
    expect(order.status, OrderStatus.menungguPersetujuanKlien);
    expect(order.penawaranMenunggu!.harga, 200000);
    expect(find.text('Setuju & Bayar'), findsOneWidget);
  });

  testWidgets('panel penawaran tidak muncul di order Jalur A', (tester) async {
    // Harga Jalur A sudah pasti sejak order dibuat, tidak ada yang perlu
    // ditawarkan di sana.
    final jalurA = Order(
      id: 'o-uji',
      kodeOrder: 'SRH-9005',
      klienId: SeedData.klien.id,
      namaKlien: SeedData.klien.nama,
      serviceType: ServiceType.anterJemput,
      status: OrderStatus.menungguPembayaran,
      dibuatPada: DateTime.now(),
      harga: 11000,
    );
    await bukaDetail(tester, jalurA);

    expect(find.text('ALAT PENGUJI'), findsNothing);
  });
}
