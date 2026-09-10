import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';

import '../support/tiruan.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/app_user.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

/// Tes tombol ganti mode (rencana capstone bagian 14.3).
///
/// Yang diuji: permukaan yang terbuka ditentukan peran yang sedang dipakai,
/// bukan daftar peran yang dimiliki akun, dan mode itu tidak terbawa ke akun
/// berikutnya.
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

  Future<void> bukaAplikasi(WidgetTester tester, AppUser sebagai) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          authRepositoryProvider.overrideWith((ref) {
            final repo = FakeAuthRepository(userAwal: sebagai);
            ref.onDispose(repo.dispose);
            return repo;
          }),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> gantiMode(WidgetTester tester, String mode) async {
    await tester.tap(find.byTooltip('Ganti Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(mode));
    await tester.pumpAndSettle();
  }

  testWidgets('akun klien sekaligus runner membuka mode klien lebih dulu', (
    tester,
  ) async {
    await bukaAplikasi(tester, SeedData.klienRunner);

    // Beranda klien tidak lagi punya judul bilah atas (bagian 83); kolom cari
    // yang jadi anak pertamanya adalah penanda yang sama-sama uniknya.
    expect(find.text('Cari layanan'), findsOneWidget);
    expect(find.byTooltip('Ganti Mode'), findsOneWidget);
  });

  testWidgets('ganti mode membuka permukaan runner tanpa ganti akun', (
    tester,
  ) async {
    await bukaAplikasi(tester, SeedData.klienRunner);
    await gantiMode(tester, 'Mode Runner');

    expect(find.text('Order Masuk'), findsWidgets);
    // Akun yang masuk tidak berubah, cuma pekerjaannya yang berganti.
    expect(find.byTooltip('Ganti Mode'), findsOneWidget);
  });

  testWidgets('mode bisa dikembalikan ke klien', (tester) async {
    await bukaAplikasi(tester, SeedData.klienRunner);
    await gantiMode(tester, 'Mode Runner');
    await gantiMode(tester, 'Mode Klien');

    // Beranda klien tidak lagi punya judul bilah atas (bagian 83); kolom cari
    // yang jadi anak pertamanya adalah penanda yang sama-sama uniknya.
    expect(find.text('Cari layanan'), findsOneWidget);
  });

  testWidgets('akun satu peran tidak diberi tombol ganti mode', (tester) async {
    await bukaAplikasi(tester, SeedData.klien);

    expect(find.byTooltip('Ganti Mode'), findsNothing);
  });

  testWidgets('akun admin sekaligus runner tidak diberi tombol ganti mode', (
    tester,
  ) async {
    // Dua peran, tapi satu permukaan: admin bekerja lewat dashboard web.
    // Tombol yang tidak menuju ke mana-mana lebih membingungkan daripada
    // tidak ada tombol sama sekali.
    await bukaAplikasi(tester, SeedData.adminRunner);

    expect(find.text('Order Masuk'), findsWidgets);
    expect(find.byTooltip('Ganti Mode'), findsNothing);
  });

  testWidgets('akun admin saja diberi keterangan, dan tetap bisa keluar', (
    tester,
  ) async {
    // Admin tidak punya permukaan mobile: pekerjaannya pekerjaan tabel dan
    // angka yang tempatnya dashboard web (bagian 14.2). Layar ini memang jalan
    // buntu, dan itu benar. Yang tidak benar adalah jalan buntu yang tidak bisa
    // ditinggalkan: sebelum ini tombol profil cuma ada di beranda klien dan
    // bilah atas runner, jadi akun seperti ini tidak punya satu pun cara keluar
    // dari akunnya.
    const adminSaja = AppUser(
      id: 'u-admin-saja',
      nama: 'Admin Saja',
      noHp: '081200000000',
      roles: {UserRole.admin},
    );
    await bukaAplikasi(tester, adminSaja);

    expect(find.text('Akun admin'), findsOneWidget);
    expect(find.textContaining('dashboard web'), findsOneWidget);

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Keluar'), findsOneWidget);
  });

  testWidgets('mode runner tidak terbawa ke akun berikutnya', (tester) async {
    // Kalau mode ikut berpindah akun, akun yang bahkan bukan runner bisa
    // terbuka sebagai runner.
    await bukaAplikasi(tester, SeedData.klienRunner);
    await gantiMode(tester, 'Mode Runner');

    await tester.tap(find.byTooltip('Ganti Akun (alat penguji)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SeedData.klien.nama));
    await tester.pumpAndSettle();

    // Beranda klien tidak lagi punya judul bilah atas (bagian 83); kolom cari
    // yang jadi anak pertamanya adalah penanda yang sama-sama uniknya.
    expect(find.text('Cari layanan'), findsOneWidget);
    expect(find.byTooltip('Ganti Mode'), findsNothing);
  });
}
