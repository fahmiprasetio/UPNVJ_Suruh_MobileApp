import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

import '../support/tiruan.dart';

/// Mengganti nomor HP sendiri: minta kode ke nomor baru, lalu konfirmasi.
///
/// Diuji lewat aplikasi utuh dari layar profil, bukan `GantiNomorHpDialog`
/// sendirian, karena yang paling mungkin salah bukan isi dialognya melainkan
/// sambungannya ke `authRepositoryProvider` yang sama dengan yang menonton
/// `userAktifProvider` -- kalau sambungan itu putus, nomor yang tampil di
/// kartu identitas tidak pernah ikut berubah walau dialognya sendiri melapor
/// berhasil.
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

  Future<FakeAuthRepository> bukaDialog(WidgetTester tester) async {
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
    await tester.tap(find.widgetWithText(TextButton, 'Ganti nomor HP'));
    await tester.pumpAndSettle();

    return authRepo;
  }

  const nomorBaru = '081399998888';

  testWidgets('alur lengkap sampai nomornya berubah di kartu identitas', (
    tester,
  ) async {
    final authRepo = await bukaDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nomor HP baru'),
      nomorBaru,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kirim kode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining(nomorBaru), findsWidgets);

    final kode = authRepo.kodeUntuk(nomorBaru);
    expect(kode, isNotNull);

    await tester.enterText(find.widgetWithText(TextFormField, 'Kode'), kode!);
    await tester.tap(find.widgetWithText(FilledButton, 'Konfirmasi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Dialognya tertutup, dan authRepositoryProvider sudah membawa nomor baru
    // -- yang membuktikan sambungannya, bukan cuma dialog yang melapor sendiri.
    expect(find.byType(AlertDialog), findsNothing);
    expect(authRepo.userAktif?.noHp, nomorBaru);

    final kartu = find.byKey(const ValueKey('kartu-identitas'));
    expect(
      find.descendant(of: kartu, matching: find.text(nomorBaru)),
      findsOneWidget,
    );
  });

  testWidgets('kode yang salah menampilkan galat, dialog tidak tertutup', (
    tester,
  ) async {
    final authRepo = await bukaDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nomor HP baru'),
      nomorBaru,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kirim kode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kode'),
      '000000',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Konfirmasi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Kode salah'), findsOneWidget);
    // Dan nomor akunnya tidak ikut berubah gara-gara percobaan yang gagal.
    expect(authRepo.userAktif?.noHp, SeedData.klien.noHp);
  });

  testWidgets('nomor yang sama dengan sekarang ditolak sebelum ke server', (
    tester,
  ) async {
    await bukaDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nomor HP baru'),
      SeedData.klien.noHp,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kirim kode'));
    await tester.pump();

    // Ditolak validator lokal: tidak ada jeda jaringan yang harus ditunggu
    // pump, dan pesannya bicara soal nomor yang sekarang, bukan soal kode
    // yang salah.
    expect(
      find.textContaining('nomor yang sekarang'),
      findsOneWidget,
    );
  });

  testWidgets('nomor yang sudah dipakai akun lain ditolak', (tester) async {
    final authRepo = await bukaDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nomor HP baru'),
      SeedData.runner.noHp,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kirim kode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('sudah dipakai akun lain'), findsOneWidget);
    expect(authRepo.userAktif?.noHp, SeedData.klien.noHp);
  });

  testWidgets('batal di langkah nomor tidak mengubah apa pun', (
    tester,
  ) async {
    final authRepo = await bukaDialog(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Batal'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(authRepo.userAktif?.noHp, SeedData.klien.noHp);
  });

  testWidgets('tautan ganti nomor di langkah kode kembali ke langkah awal', (
    tester,
  ) async {
    await bukaDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nomor HP baru'),
      nomorBaru,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kirim kode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.widgetWithText(TextFormField, 'Kode'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Ganti nomor'));
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'Nomor HP baru'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Kode'), findsNothing);
  });
}
