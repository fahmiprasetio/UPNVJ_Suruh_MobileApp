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
    // Dicari di dalam kartu identitasnya, bukan di seluruh layar: kolom sunting
    // di bawahnya berisi nama yang sama persis, jadi pencarian teks polos
    // menemukan dua-duanya dan tidak membuktikan yang mana yang tampil.
    final kartu = find.byKey(const ValueKey('kartu-identitas'));
    expect(
      find.descendant(of: kartu, matching: find.text(SeedData.klien.nama)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: kartu, matching: find.text(SeedData.klien.noHp)),
      findsOneWidget,
    );
  });

  testWidgets('runner juga punya pintu profil, bukan cuma klien', (
    tester,
  ) async {
    // Sebelum layar ini ada, pintu profil cuma ada di beranda klien, jadi akun
    // runner murni tidak punya cara keluar dari akunnya sama sekali. Itu
    // separuh pengguna aplikasi ini.
    await buka(tester, SeedData.runner);

    expect(find.widgetWithText(AppBar, 'Profil'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('kartu-identitas')),
        matching: find.text(SeedData.runner.nama),
      ),
      findsOneWidget,
    );
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

  testWidgets('nama yang disunting tersimpan, dan tampil di layar', (
    tester,
  ) async {
    final authRepo = await buka(tester, SeedData.klien);

    await tester.enterText(
      find.widgetWithText(TextFormField, SeedData.klien.nama),
      'Dina Rahmawati Putri',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(authRepo.userAktif?.nama, 'Dina Rahmawati Putri');
    expect(authRepo.userAktif?.noHp, SeedData.klien.noHp);
    // Perannya tidak ikut berubah, dan itu bukan pemeriksaan basa-basi: satu
    // method di jalur ini yang lalai menyalin peran berarti klien kehilangan
    // seluruh permukaannya begitu ia membetulkan namanya.
    expect(authRepo.userAktif?.roles, SeedData.klien.roles);
  });

  testWidgets('alamat bisa dikosongkan lagi sesudah pernah diisi', (
    tester,
  ) async {
    // Kemampuan yang paling mudah hilang tanpa disadari, karena `copyWith`
    // memperlakukan null sebagai "jangan diubah" — dan orang yang pindah kos
    // adalah persis orang yang membutuhkannya.
    final authRepo = await buka(tester, SeedData.klien);

    await tester.enterText(
      find.widgetWithText(TextFormField, SeedData.klien.alamat!),
      '',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(authRepo.userAktif?.alamat, isNull);
  });

  testWidgets('simpan mati selama tidak ada yang berubah', (tester) async {
    await buka(tester, SeedData.klien);

    final tombol = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Simpan'),
    );
    expect(tombol.onPressed, isNull);
  });

  testWidgets('nomor HP tidak punya kolom isian sama sekali', (tester) async {
    // Bukan kolom mati: kolom yang tidak bisa diisi mengundang orangnya mencoba
    // lalu menyimpulkan aplikasinya rusak.
    await buka(tester, SeedData.klien);

    expect(
      find.widgetWithText(TextFormField, SeedData.klien.noHp),
      findsNothing,
    );
    expect(find.textContaining('Nomor HP tidak bisa diubah'), findsOneWidget);
  });
}
