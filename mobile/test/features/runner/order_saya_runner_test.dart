import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';
import '../../support/tiruan.dart';

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

  /// Membuka aplikasi sebagai runner lalu berpindah ke tab Order Saya.
  Future<FakeOrderRepository> bukaOrderSaya(
    WidgetTester tester, {
    List<Order>? orderAwal,
  }) async {
    final orderRepo = FakeOrderRepository(
      pemanggil: () => SeedData.runner.id,
      orderAwal: orderAwal);
    addTearDown(orderRepo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          orderRepositoryProvider.overrideWith((ref) => orderRepo),
          authRepositoryProvider.overrideWith((ref) {
            final repo = FakeAuthRepository(userAwal: SeedData.runner);
            ref.onDispose(repo.dispose);
            return repo;
          }),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationBar, 'Order Saya'));
    await tester.pumpAndSettle();
    return orderRepo;
  }

  /// Jeda unggah foto palsu 600 ms hanya lewat kalau layarnya dipompa.
  Future<void> ambilFotoBukti(WidgetTester tester) async {
    await tester.tap(find.text('Ambil Foto Bukti'));
    await tester.pump();
    expect(find.text('Mengunggah foto...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('order yang dipegang dipisah dari yang sudah selesai', (
    tester,
  ) async {
    await bukaOrderSaya(tester);

    // Dari data contoh: SRH-0410 sedang dikerjakan, SRH-0398 sudah selesai.
    expect(find.text('Sedang dikerjakan (1)'), findsOneWidget);
    expect(find.text('Sudah selesai (1)'), findsOneWidget);
    expect(find.text('Selesaikan Order'), findsOneWidget);
  });

  testWidgets('runner tanpa order sama sekali diberi keterangan', (
    tester,
  ) async {
    await bukaOrderSaya(tester, orderAwal: const []);

    expect(find.text('Belum ada order yang kamu pegang'), findsOneWidget);
  });

  testWidgets('layar kosong menawarkan jalan keluar, bukan jalan buntu', (
    tester,
  ) async {
    await bukaOrderSaya(tester, orderAwal: const []);

    await tester.tap(find.text('Lihat Order Masuk'));
    await tester.pumpAndSettle();

    // Berpindah tab, bukan mendorong rute baru. Kalau suatu saat tombol ini
    // diganti jadi `context.push`, dua daftar order masuk akan menumpuk di
    // riwayat navigasi dan tombol kembali akan melewati satu layar hantu.
    expect(find.widgetWithText(AppBar, 'Order Masuk'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('tombol selesai mati sampai foto buktinya ada', (tester) async {
    await bukaOrderSaya(tester);

    await tester.tap(find.text('Selesaikan Order'));
    await tester.pumpAndSettle();

    FilledButton tombolSelesai() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tandai Selesai'),
    );

    expect(tombolSelesai().onPressed, isNull);

    await ambilFotoBukti(tester);

    expect(find.text('Foto bukti terkirim'), findsOneWidget);
    expect(tombolSelesai().onPressed, isNotNull);
  });

  testWidgets('layar mengaku bahwa fotonya belum sungguhan', (tester) async {
    await bukaOrderSaya(tester);

    await tester.tap(find.text('Selesaikan Order'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ALAT PENGUJI'), findsOneWidget);
  });

  testWidgets('menandai selesai menutup order beserta catatannya', (
    tester,
  ) async {
    final repo = await bukaOrderSaya(tester);

    await tester.tap(find.text('Selesaikan Order'));
    await tester.pumpAndSettle();

    await ambilFotoBukti(tester);

    await tester.enterText(
      find.byType(TextField),
      'Makanan dititipkan ke penjaga kos',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tandai Selesai'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Order SRH-0410 ditandai selesai.'), findsOneWidget);
    expect(find.text('Sudah selesai (2)'), findsOneWidget);

    final order = (await repo.watchOrder('o-2').first)!;
    expect(order.status, OrderStatus.selesai);
    expect(order.fotoBuktiUrl, startsWith('fake://bukti/'));
    expect(order.catatanSerahTerima, 'Makanan dititipkan ke penjaga kos');
  });

  testWidgets('order yang sudah selesai tidak menawarkan tindakan lagi', (
    tester,
  ) async {
    await bukaOrderSaya(
      tester,
      orderAwal: [
        Order(
          id: 'o-selesai',
          kodeOrder: 'SRH-9002',
          klienId: SeedData.klien.id,
          namaKlien: SeedData.klien.nama,
          serviceType: ServiceType.anterJemput,
          status: OrderStatus.selesai,
          dibuatPada: DateTime.now(),
          harga: 11000,
          runnerIds: [SeedData.runner.id],
          selesaiPada: DateTime.now(),
          fotoBuktiUrl: 'fake://bukti/o-selesai.jpg',
        ),
      ],
    );

    expect(find.text('Selesaikan Order'), findsNothing);
    expect(find.text('Foto bukti tersimpan'), findsOneWidget);
  });
}
