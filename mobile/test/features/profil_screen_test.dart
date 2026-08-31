import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/models/app_user.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

import '../support/tiruan.dart';

/// Profil diuji lewat aplikasi utuh, bukan layarnya sendirian, karena yang
/// paling mungkin salah bukan isi layarnya melainkan dua sambungannya: apakah
/// pintunya benar-benar ada di kedua permukaan, dan apakah keluar benar-benar
/// mengantar pengguna kembali ke layar masuk.
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

  Future<FakeAuthRepository> buka(WidgetTester tester, AppUser sebagai) async {
    final authRepo = FakeAuthRepository(userAwal: sebagai);
    addTearDown(authRepo.dispose);
    final orderRepo = FakeOrderRepository(pemanggil: () => sebagai.id);
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
    return authRepo;
  }

  testWidgets('klien menemukan pintu profil dan melihat akunnya', (
    tester,
  ) async {
    await buka(tester, SeedData.klien);

    expect(find.widgetWithText(AppBar, 'Profil'), findsOneWidget);
    expect(find.text(SeedData.klien.nama), findsOneWidget);
    expect(find.text(SeedData.klien.noHp), findsOneWidget);
  });

  testWidgets('runner juga punya pintu profil, bukan cuma klien', (
    tester,
  ) async {
    // Sebelum layar ini ada, pintu profil cuma ada di beranda klien, jadi akun
    // runner murni tidak punya cara keluar dari akunnya sama sekali. Itu
    // separuh pengguna aplikasi ini.
    await buka(tester, SeedData.runner);

    expect(find.widgetWithText(AppBar, 'Profil'), findsOneWidget);
    expect(find.text(SeedData.runner.nama), findsOneWidget);
  });

  testWidgets('keluar bertanya dulu, dan batal berarti tetap masuk', (
    tester,
  ) async {
    final authRepo = await buka(tester, SeedData.klien);

    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari akun?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    // Masuk kembali menuntut menunggu SMS dan mengetik enam angka, jadi salah
    // tekan di sini berbiaya menit, bukan detik.
    expect(authRepo.userAktif, isNotNull);
    expect(find.widgetWithText(AppBar, 'Profil'), findsOneWidget);
  });

  testWidgets('keluar yang dibenarkan mengantar kembali ke layar masuk', (
    tester,
  ) async {
    final authRepo = await buka(tester, SeedData.klien);

    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
    await tester.pumpAndSettle();

    expect(authRepo.userAktif, isNull);
    // Yang memindahkan layar adalah router yang menyimak sesi, bukan layar
    // profil yang mendorong dirinya sendiri. Kalau suatu saat layar ini
    // menavigasi sendiri, layar profil akan tertinggal di tumpukan belakang
    // layar masuk dan tombol kembali membawa pengguna ke profil akun yang
    // sudah tidak ada.
    expect(find.text('Belum punya akun? Daftar'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });
}
