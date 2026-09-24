import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/core/widgets/tombol_notifikasi.dart';
import 'package:upnvj_suruh/core/providers/repository_providers.dart';

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

  Future<void> bangunAplikasi(WidgetTester tester) async {
    final authRepo = FakeAuthRepository(userAwal: SeedData.klien);
    addTearDown(authRepo.dispose);
    final orderRepo = FakeOrderRepository(pemanggil: () => SeedData.klien.id);
    addTearDown(orderRepo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          authRepositoryProvider.overrideWith((ref) => authRepo),
          orderRepositoryProvider.overrideWith((ref) => orderRepo),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mengetuk TombolNotifikasi di beranda membuka layar Notifikasi', (
    tester,
  ) async {
    await bangunAplikasi(tester);

    expect(find.byType(TombolNotifikasi), findsOneWidget);
    await tester.tap(find.byType(TombolNotifikasi));
    await tester.pumpAndSettle();

    expect(find.text('Notifikasi'), findsOneWidget);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Pesanan'), findsOneWidget);
    expect(find.text('Info & Tips'), findsOneWidget);
  });

  testWidgets('filter Info & Tips menampilkan pengumuman kampus dan membuka dialog info saat diketuk', (
    tester,
  ) async {
    await bangunAplikasi(tester);

    await tester.tap(find.byType(TombolNotifikasi));
    await tester.pumpAndSettle();

    // Pilih tab Info & Tips
    await tester.tap(find.text('Info & Tips'));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang di UPNVJ Suruh!'), findsOneWidget);
    expect(find.text('Pembayaran Cepat & Otomatis via QRIS'), findsOneWidget);

    // Ketuk salah satu pengumuman untuk membuka modal detail
    await tester.tap(find.text('Selamat Datang di UPNVJ Suruh!'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Tutup'), findsOneWidget);

    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('filter Pesanan menyaring pembaruan pesanan milik klien', (
    tester,
  ) async {
    await bangunAplikasi(tester);

    await tester.tap(find.byType(TombolNotifikasi));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pesanan'));
    await tester.pumpAndSettle();

    // SeedData klien memiliki beberapa order lama/aktif
    expect(find.byType(FilterChip), findsNWidgets(3));
  });
}
