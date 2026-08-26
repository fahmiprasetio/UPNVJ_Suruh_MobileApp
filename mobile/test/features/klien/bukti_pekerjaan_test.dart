import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/features/klien/detail_order/widgets/kartu_bukti_pekerjaan.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

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

  /// Membuka detail satu order dari daftar order klien.
  Future<void> bukaDetail(
    WidgetTester tester,
    String kodeOrder, {
    List<Order>? orderAwal,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (orderAwal != null)
            orderRepositoryProvider.overrideWith((ref) {
              final repo = FakeOrderRepository(orderAwal: orderAwal);
              ref.onDispose(repo.dispose);
              return repo;
            }),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Order Saya'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(kodeOrder));
    await tester.pumpAndSettle();
  }

  Order orderSelesai({
    String fotoBuktiUrl = 'fake://bukti/o-uji.jpg',
    String? catatanSerahTerima,
  }) {
    return Order(
      id: 'o-uji',
      kodeOrder: 'SRH-9003',
      klienId: SeedData.klien.id,
      namaKlien: SeedData.klien.nama,
      serviceType: ServiceType.jastipBarang,
      status: OrderStatus.selesai,
      dibuatPada: DateTime.now().subtract(const Duration(hours: 2)),
      harga: 12000,
      runnerIds: [SeedData.runner.id],
      selesaiPada: DateTime.now().subtract(const Duration(hours: 1)),
      fotoBuktiUrl: fotoBuktiUrl,
      catatanSerahTerima: catatanSerahTerima,
    );
  }

  testWidgets('klien melihat hasil pekerjaan setelah order selesai', (
    tester,
  ) async {
    await bukaDetail(tester, 'SRH-0398');

    expect(find.text('Hasil pekerjaan'), findsOneWidget);
    expect(
      find.text('Paket dititipkan ke penjaga kos, sudah difoto.'),
      findsOneWidget,
    );
  });

  testWidgets('order yang belum selesai tidak memunculkan hasil pekerjaan', (
    tester,
  ) async {
    await bukaDetail(tester, 'SRH-0411');

    expect(find.text('Hasil pekerjaan'), findsNothing);
  });

  testWidgets('foto tiruan diakui belum bisa ditampilkan, bukan dipaksa', (
    tester,
  ) async {
    await bukaDetail(tester, 'SRH-9003', orderAwal: [orderSelesai()]);

    expect(
      find.textContaining('belum bisa ditampilkan'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('foto dengan tautan sungguhan digambar apa adanya', (
    tester,
  ) async {
    await bukaDetail(
      tester,
      'SRH-9003',
      orderAwal: [
        orderSelesai(fotoBuktiUrl: 'https://contoh.test/bukti/o-uji.jpg'),
      ],
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('belum bisa ditampilkan'), findsNothing);
  });

  testWidgets('catatan runner ikut sampai ke klien', (tester) async {
    await bukaDetail(
      tester,
      'SRH-9003',
      orderAwal: [
        orderSelesai(catatanSerahTerima: 'Barang ditaruh di meja resepsionis'),
      ],
    );

    expect(find.text('Catatan runner'), findsOneWidget);
    expect(
      find.text('Barang ditaruh di meja resepsionis'),
      findsOneWidget,
    );
  });

  test('hanya tautan http yang dianggap bisa digambar', () {
    expect(
      KartuBuktiPekerjaan.bisaDigambar('https://contoh.test/a.jpg'),
      isTrue,
    );
    expect(KartuBuktiPekerjaan.bisaDigambar('http://contoh.test/a.jpg'), isTrue);
    expect(KartuBuktiPekerjaan.bisaDigambar('fake://bukti/a.jpg'), isFalse);
  });
}
