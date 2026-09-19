import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

import '../../support/tiruan.dart';

/// Layar Pengaturan lahir sesi 82, dipoles sesi 83, tapi belum punya satu pun
/// tes sendiri (lihat catatan progres bagian 10) -- sejauh ini cuma dilalui
/// tanpa sengaja lewat `atur_password_dialog_test.dart` yang berhenti begitu
/// sampai ke baris Password. Dua yang sungguhan diuji di sini: pintu yang
/// masih "menyusul" (sisanya memanggil fungsi privat yang sama, jadi satu
/// contoh cukup membuktikan mekanismenya), dan Tampilan yang benar-benar
/// mengganti tema.
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

  Future<void> bukaPengaturan(WidgetTester tester) async {
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

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Pengaturan'));
    await tester.pumpAndSettle();
  }

  testWidgets('pintu yang belum dibuat menjawab menyusul, tidak membuka apa pun', (
    tester,
  ) async {
    await bukaPengaturan(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Notifikasi'));
    await tester.pump();

    expect(find.text('Notifikasi belum dibuat, menyusul.'), findsOneWidget);
    // Tetap di layar Pengaturan, bukan pindah ke layar lain.
    expect(find.text('Pengaturan'), findsOneWidget);
  });

  testWidgets('memilih Gelap di Tampilan mengganti tema dan subjudulnya', (
    tester,
  ) async {
    await bukaPengaturan(tester);

    expect(find.text('Terang'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Tampilan'));
    await tester.pumpAndSettle();

    expect(find.text('Tampilan'), findsWidgets);
    await tester.tap(find.widgetWithText(ListTile, 'Gelap'));
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDialog), findsNothing);
    expect(find.text('Gelap'), findsOneWidget);
    expect(find.text('Terang'), findsNothing);
  });

  testWidgets('mengetuk Pusat Bantuan membuka layar pusat bantuan', (tester) async {
    await bukaPengaturan(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Pusat Bantuan'));
    await tester.pumpAndSettle();

    expect(find.text('Butuh Bantuan Mendesak?'), findsOneWidget);
    expect(find.text('Pertanyaan yang Sering Diajukan'), findsOneWidget);
  });

  testWidgets('mengetuk Syarat & Ketentuan membuka layar syarat ketentuan', (tester) async {
    await bukaPengaturan(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Syarat & Ketentuan'));
    await tester.pumpAndSettle();

    expect(find.text('Syarat & Ketentuan Layanan'), findsOneWidget);
    expect(find.text('1. Ketentuan Umum'), findsOneWidget);
  });

  testWidgets('mengetuk Kebijakan Privasi membuka layar kebijakan privasi', (tester) async {
    await bukaPengaturan(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Kebijakan Privasi'));
    await tester.pumpAndSettle();

    expect(find.text('Penggunaan Nomor Telepon'), findsOneWidget);
    expect(find.text('Pembersihan Metadata Foto (EXIF)'), findsOneWidget);
  });

  testWidgets('mengetuk Tentang Aplikasi membuka layar tentang aplikasi', (tester) async {
    await bukaPengaturan(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Tentang Aplikasi'));
    await tester.pumpAndSettle();

    expect(find.text('Versi 1.0.0 (Build Capstone)'), findsOneWidget);
    expect(find.text('Profil Mitra Inisiatif'), findsOneWidget);
  });
}
