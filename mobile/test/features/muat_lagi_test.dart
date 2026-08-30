import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/core/config/batas_halaman.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';
import 'package:upnvj_suruh/providers/ukuran_daftar.dart';

import '../support/tiruan.dart';

/// Jalan menuju baris yang tidak muat di jendela pertama.
///
/// Daftar order sekarang berbatas: server mengirim sepotong, bukan seluruhnya. Tanpa
/// jalan memperlebarnya, potongan itu jadi batas yang tidak bisa dilewati siapa pun,
/// dan riwayat lama hilang tanpa ada yang memberitahu bahwa ia pernah ada. Itu
/// kegagalan yang tidak akan dilaporkan siapa pun, karena dari layar ia terlihat
/// seperti riwayat yang memang segitu.
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

  /// Sekian order milik klien contoh, semuanya sudah selesai supaya urutannya tetap.
  List<Order> orderSebanyak(int jumlah) => [
    for (var i = 0; i < jumlah; i++)
      Order(
        id: 'o-$i',
        kodeOrder: 'SRH-${9000 + i}',
        klienId: SeedData.klien.id,
        namaKlien: SeedData.klien.nama,
        serviceType: ServiceType.jastipMakanan,
        status: OrderStatus.selesai,
        dibuatPada: DateTime.now().subtract(Duration(hours: jumlah - i)),
        harga: 12000,
        runnerIds: const [],
        selesaiPada: DateTime.now().subtract(Duration(minutes: jumlah - i)),
      ),
  ];

  Future<void> bukaRiwayat(WidgetTester tester, List<Order> orderAwal) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
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
  }

  testWidgets('riwayat yang lebih panjang dari jendela menawarkan muat lagi', (
    tester,
  ) async {
    await bukaRiwayat(tester, orderSebanyak(BatasHalaman.bawaan + 5));

    final tombol = find.textContaining('Muat 5 order lagi');
    await tester.scrollUntilVisible(tombol, 300);

    expect(tombol, findsOneWidget);
  });

  testWidgets('riwayat yang muat seluruhnya tidak menawarkan apa-apa', (
    tester,
  ) async {
    // Tombol yang selalu ada tapi tidak melakukan apa-apa lebih buruk daripada tidak
    // ada tombolnya: ia mengajak orang menekan sesuatu yang tidak mengubah layar.
    await bukaRiwayat(tester, orderSebanyak(3));

    expect(find.textContaining('Muat'), findsNothing);
  });

  testWidgets('menekan muat lagi membawa sisanya', (tester) async {
    await bukaRiwayat(tester, orderSebanyak(BatasHalaman.bawaan + 5));

    final tombol = find.textContaining('Muat 5 order lagi');
    await tester.scrollUntilVisible(tombol, 300);
    // scrollUntilVisible berhenti begitu widgetnya ketemu, belum tentu setelah
    // ia utuh di layar. Kalau tombolnya berhenti tepat di tepi bawah, ketukan
    // di titik tengahnya jatuh di luar viewport dan tidak sampai ke mana-mana,
    // dan tesnya gagal dengan cara yang terbaca seperti tombolnya tidak bekerja.
    await tester.ensureVisible(tombol);
    await tester.pumpAndSettle();
    await tester.tap(tombol);
    await tester.pumpAndSettle();

    // Hilang karena sudah tidak ada sisanya, bukan karena layarnya bergeser.
    expect(find.textContaining('Muat'), findsNothing);

    // Judul bagiannya menyebut jumlah yang benar-benar terbawa. Digulung ke atas dulu
    // karena menekan tombol tadi meninggalkan layar di ujung bawah daftar.
    final judul = find.textContaining('Sudah selesai (25)');
    await tester.scrollUntilVisible(judul, -300);
    expect(judul, findsOneWidget);
  });

  testWidgets('daftar yang sudah tampil tidak berkedip saat jendelanya melebar', (
    tester,
  ) async {
    // Memperbesar jendela menghitung ulang providernya, dan tanpa skipLoadingOnReload
    // layar berganti jadi pemuat tepat pada saat orang sedang menatapnya.
    await bukaRiwayat(tester, orderSebanyak(BatasHalaman.bawaan + 5));

    final tombol = find.textContaining('Muat 5 order lagi');
    await tester.scrollUntilVisible(tombol, 300);
    // scrollUntilVisible berhenti begitu widgetnya ketemu, belum tentu setelah
    // ia utuh di layar. Kalau tombolnya berhenti tepat di tepi bawah, ketukan
    // di titik tengahnya jatuh di luar viewport dan tidak sampai ke mana-mana,
    // dan tesnya gagal dengan cara yang terbaca seperti tombolnya tidak bekerja.
    await tester.ensureVisible(tombol);
    await tester.pumpAndSettle();
    await tester.tap(tombol);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  group('ukuran jendela', () {
    test('bertambah sebanyak tambahannya', () {
      final wadah = ProviderContainer();
      addTearDown(wadah.dispose);

      wadah.read(ukuranOrderKlienProvider.notifier).perbesar();

      expect(
        wadah.read(ukuranOrderKlienProvider),
        BatasHalaman.bawaan + BatasHalaman.tambahan,
      );
    });

    test('berhenti di batas yang diterima server', () {
      // Server menolak ukuran di atas batasnya, jadi jendela yang terus membesar akan
      // berujung pada daftar yang gagal dimuat sama sekali, bukan daftar yang panjang.
      final wadah = ProviderContainer();
      addTearDown(wadah.dispose);

      final notifier = wadah.read(ukuranOrderKlienProvider.notifier);
      for (var i = 0; i < 20; i++) {
        notifier.perbesar();
      }

      expect(wadah.read(ukuranOrderKlienProvider), BatasHalaman.maksimal);
      expect(notifier.bisaDiperbesar, isFalse);
    });

    test('tiap daftar punya jendelanya sendiri', () {
      // Kalau jendelanya dibagi, menekan muat lagi di riwayat klien akan diam-diam
      // memperbesar permintaan daftar siaran runner juga.
      final wadah = ProviderContainer();
      addTearDown(wadah.dispose);

      wadah.read(ukuranOrderKlienProvider.notifier).perbesar();

      expect(wadah.read(ukuranOrderRunnerProvider), BatasHalaman.bawaan);
      expect(wadah.read(ukuranOrderTersiarProvider), BatasHalaman.bawaan);
    });
  });
}
