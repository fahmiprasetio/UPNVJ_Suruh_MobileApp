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
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
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
      orderAwal: orderAwal,
    );
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

    // Labelnya yang diketuk, bukan NavigationBar-nya. Mengetuk bilahnya berarti
    // mengetuk titik tengahnya, yaitu tab yang kebetulan ada di tengah, dan itu
    // berpindah begitu ada tab yang ditambahkan (Pendapatan, sejak layar
    // pendapatan runner ada).
    await tester.tap(find.text('Order Saya').last);
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

  testWidgets('alamat jemput tidak hilang setelah ordernya diterima', (
    tester,
  ) async {
    // Order antar jemput yang sudah dipegang runner ini. Di kartu siaran kedua
    // alamatnya terbaca jelas; kalau setelah TERIMA yang tersisa cuma alamat
    // tujuan, runner kehilangan setengah rutenya tepat ketika ia mulai
    // membutuhkannya, dan satu-satunya jalan mendapatkannya kembali adalah
    // bertanya lewat chat.
    final anterJemput = SeedData.orderAwal().first.copyWith(
      status: OrderStatus.dikerjakan,
      runnerIds: [SeedData.runner.id],
    );
    await bukaOrderSaya(tester, orderAwal: [anterJemput]);

    expect(
      find.text('Kos Melati, Jl. Pondok Labu Raya No. 12'),
      findsOneWidget,
    );
    expect(find.text('Gedung Fakultas Ilmu Komputer UPNVJ'), findsOneWidget);
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

  /// Runner yang sudah menekan terima dulu tidak punya jalan keluar sama sekali:
  /// ordernya menggantung sampai ia memaksa menandainya selesai, atau admin
  /// membatalkan seluruhnya berikut pengembalian dana padahal yang dibutuhkan klien
  /// cuma runner lain.
  group('melepas order', () {
    testWidgets('ditawarkan untuk order yang sedang dikerjakan', (tester) async {
      await bukaOrderSaya(tester);

      expect(find.text('Lepas order'), findsOneWidget);
    });

    /// Mengembalikan order yang sudah diserahkan ke "mencari runner" berarti
    /// pekerjaan yang sudah dibayar dan sudah selesai disiarkan ulang.
    testWidgets('tidak ditawarkan untuk order yang sudah selesai', (tester) async {
      await bukaOrderSaya(
        tester,
        orderAwal: [
          Order(
            id: 'o-selesai',
            kodeOrder: 'SRH-9003',
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

      expect(find.text('Lepas order'), findsNothing);
    });

    testWidgets('menuntut alasan sebelum tombolnya bisa ditekan', (tester) async {
      await bukaOrderSaya(tester);

      await tester.tap(find.text('Lepas order'));
      await tester.pumpAndSettle();

      // Tombol di dialognya, bukan tombol di kartu yang tadi ditekan.
      final tombolLepas = find.widgetWithText(TextButton, 'Lepas');
      expect(tester.widget<TextButton>(tombolLepas).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Motor saya mogok.');
      await tester.pump();

      expect(tester.widget<TextButton>(tombolLepas).onPressed, isNotNull);
    });

    testWidgets('order yang dilepas hilang dari daftar pekerjaan runner', (
      tester,
    ) async {
      await bukaOrderSaya(tester);
      expect(find.text('Sedang dikerjakan (1)'), findsOneWidget);

      await tester.tap(find.text('Lepas order'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Motor saya mogok.');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Lepas'));
      await tester.pumpAndSettle();

      expect(find.text('Sedang dikerjakan (1)'), findsNothing);
    });
  });
}
