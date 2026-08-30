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

  /// Membuka aplikasi sebagai runner. Peran akun yang menentukan permukaan
  /// mana yang terbuka, jadi tidak ada navigasi khusus yang perlu dilakukan.
  Future<FakeOrderRepository> bukaSebagaiRunner(
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
    return orderRepo;
  }

  /// Menekan TERIMA lalu menunggu jawabannya.
  ///
  /// Tidak boleh langsung `pumpAndSettle`: selama permintaan di jalan tombol
  /// menampilkan spinner, dan spinner berputar selamanya, `pumpAndSettle`
  /// akan menunggu sampai kehabisan waktu. Jeda dilewati dengan `pump`
  /// bertempo, sekalian membuktikan tombolnya memang terkunci.
  Future<void> tekanTerima(WidgetTester tester) async {
    await tester.tap(find.text('TERIMA'));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  /// Membaca keadaan order tanpa memanggil [FakeOrderRepository.getOrder].
  ///
  /// Di tes widget waktu hanya berjalan saat layar dipompa, sedangkan
  /// `getOrder` menunggu jeda jaringan palsu, menantinya langsung membuat tes
  /// berhenti selamanya. Aliran `watchOrder` memancarkan keadaan sekarang
  /// tanpa jeda, jadi aman ditunggu dari dalam tes.
  Future<Order> bacaOrder(FakeOrderRepository repo, String orderId) async =>
      (await repo.watchOrder(orderId).first)!;

  Order orderSiaran({
    String id = 'o-uji',
    String kodeOrder = 'SRH-9001',
    int jumlahRunnerDibutuhkan = 1,
    List<String> runnerIds = const [],
  }) {
    return Order(
      id: id,
      kodeOrder: kodeOrder,
      klienId: SeedData.klien.id,
      namaKlien: SeedData.klien.nama,
      serviceType: ServiceType.anterJemput,
      status: OrderStatus.mencariRunner,
      dibuatPada: DateTime.now(),
      alamatJemput: 'Kos Melati',
      alamatTujuan: 'Gedung FIK UPNVJ',
      harga: 11000,
      jumlahRunnerDibutuhkan: jumlahRunnerDibutuhkan,
      runnerIds: runnerIds,
    );
  }

  testWidgets('akun runner membuka layar Order Masuk, bukan beranda klien', (
    tester,
  ) async {
    await bukaSebagaiRunner(tester);

    // 'Order Masuk' kini muncul dua kali: judul layar dan label tab.
    expect(find.widgetWithText(AppBar, 'Order Masuk'), findsOneWidget);
    expect(find.widgetWithText(NavigationBar, 'Order Masuk'), findsOneWidget);
    expect(find.text('Mau disuruh apa hari ini?'), findsNothing);
  });

  testWidgets('hanya order yang sedang mencari runner yang disiarkan', (
    tester,
  ) async {
    await bukaSebagaiRunner(tester);

    // Dari data contoh: SRH-0411 mencari runner, sisanya tidak.
    expect(find.textContaining('SRH-0411'), findsOneWidget);
    expect(find.textContaining('SRH-0410'), findsNothing);
    expect(find.textContaining('SRH-0409'), findsNothing);
  });

  testWidgets('daftar kosong menjelaskan keadaannya, bukan diam', (
    tester,
  ) async {
    await bukaSebagaiRunner(tester, orderAwal: const []);

    expect(find.text('Belum ada order masuk'), findsOneWidget);
  });

  testWidgets('menerima order membuatnya berhenti disiarkan', (tester) async {
    final repo = await bukaSebagaiRunner(tester, orderAwal: [orderSiaran()]);

    await tekanTerima(tester);

    expect(
      find.text('Order SRH-9001 jadi milikmu. Segera kerjakan, ya.'),
      findsOneWidget,
    );
    expect(find.text('Belum ada order masuk'), findsOneWidget);

    final order = await bacaOrder(repo, 'o-uji');
    expect(order.runnerIds, [SeedData.runner.id]);
    expect(order.status, OrderStatus.dikerjakan);
  });

  testWidgets('runner yang kalah cepat diberi tahu, bukan dibiarkan menebak', (
    tester,
  ) async {
    final repo = await bukaSebagaiRunner(tester, orderAwal: [orderSiaran()]);

    // Runner lain menekan TERIMA lebih dulu; permintaannya sudah di jalan
    // ketika runner ini ikut menekan.
    final pesaing = repo.terimaOrderSebagai(
      orderId: 'o-uji',
      runnerId: SeedData.adminRunner.id,
    );
    await tekanTerima(tester);

    expect(await pesaing, isTrue);
    expect(
      find.text('Order SRH-9001 keburu diambil runner lain.'),
      findsOneWidget,
    );
    expect(
      (await bacaOrder(repo, 'o-uji')).runnerIds,
      [SeedData.adminRunner.id],
    );
  });

  testWidgets('order multi-runner menampilkan sisa kuotanya', (tester) async {
    await bukaSebagaiRunner(
      tester,
      orderAwal: [
        orderSiaran(
          jumlahRunnerDibutuhkan: 3,
          runnerIds: const ['u-runner-9'],
        ),
      ],
    );

    expect(find.text('Butuh 3 orang · 1 sudah gabung'), findsOneWidget);
  });

  testWidgets('order yang sudah kuambil tidak ditawarkan lagi', (tester) async {
    await bukaSebagaiRunner(
      tester,
      orderAwal: [
        orderSiaran(
          jumlahRunnerDibutuhkan: 3,
          runnerIds: [SeedData.runner.id],
        ),
      ],
    );

    // Kuotanya masih terbuka, tapi bukan untuk runner ini.
    expect(find.text('TERIMA'), findsNothing);
    expect(find.text('Belum ada order masuk'), findsOneWidget);
    // Pekerjaan yang belum kelar ditandai lencana di tab Order Saya.
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('1')),
      findsOneWidget,
    );
  });
}
