import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/features/klien/beranda/widgets/lembar_cari_layanan.dart';
import 'package:upnvj_suruh/features/klien/order_jalur_b/form_permintaan_screen.dart';
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

  group('Fungsi saringKatalogLayanan', () {
    test('kueri kosong mengembalikan seluruh katalog layanan', () {
      final hasil = saringKatalogLayanan('');
      expect(hasil.length, 7);
    });

    test('kueri makanan mencocokkan Jastip Makanan', () {
      final hasil = saringKatalogLayanan('makanan');
      expect(hasil.any((l) => l.type == ServiceType.jastipMakanan), isTrue);
    });

    test('kata kunci sinonim motor mencocokkan Anter Jemput', () {
      final hasil = saringKatalogLayanan('motor');
      expect(hasil.any((l) => l.type == ServiceType.anterJemput), isTrue);
    });

    test('kata kunci toilet mencocokkan Bersih Kamar Mandi', () {
      final hasil = saringKatalogLayanan('toilet');
      expect(hasil.any((l) => l.type == ServiceType.bersihKamarMandi), isTrue);
    });

    test('kueri tanpa kecocokan mengembalikan daftar kosong', () {
      final hasil = saringKatalogLayanan('pesawat_terbang_123');
      expect(hasil.isEmpty, isTrue);
    });
  });

  group('Widget LembarCariLayanan di Beranda', () {
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

    testWidgets('mengetuk bilah pencarian membuka lembar pencarian layanan', (
      tester,
    ) async {
      await bangunAplikasi(tester);

      await tester.tap(find.text('Cari layanan'));
      await tester.pumpAndSettle();

      expect(find.byType(LembarCariLayanan), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(ActionChip), findsWidgets);
    });

    testWidgets('mengetik kata kunci menyaring layanan dan membukanya saat diketuk', (
      tester,
    ) async {
      await bangunAplikasi(tester);

      await tester.tap(find.text('Cari layanan'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'kamar mandi');
      await tester.pumpAndSettle();

      final hasilKamarMandi = find.descendant(
        of: find.byType(LembarCariLayanan),
        matching: find.text('Bersih Kamar Mandi'),
      );
      expect(hasilKamarMandi, findsOneWidget);

      await tester.tap(hasilKamarMandi);
      await tester.pumpAndSettle();

      // Form Jalur B untuk Bersih Kamar Mandi terbuka
      expect(find.byType(LembarCariLayanan), findsNothing);
      expect(find.byType(FormPermintaanScreen), findsOneWidget);
    });

    testWidgets('pencarian tanpa hasil menampilkan opsi Permintaan Lain', (
      tester,
    ) async {
      await bangunAplikasi(tester);

      await tester.tap(find.text('Cari layanan'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'layanan_asing_tidak_ada');
      await tester.pumpAndSettle();

      expect(find.text('Layanan tidak ditemukan'), findsOneWidget);
      expect(find.text('Buat Permintaan Lain'), findsOneWidget);

      await tester.tap(find.text('Buat Permintaan Lain'));
      await tester.pumpAndSettle();

      expect(find.byType(LembarCariLayanan), findsNothing);
      expect(find.byType(FormPermintaanScreen), findsOneWidget);
    });
  });
}
