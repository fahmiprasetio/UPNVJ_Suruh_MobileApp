import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/core/providers/repository_providers.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/features/auth/masuk_screen.dart';

import '../support/tiruan.dart';

/// Menghapus akun sendiri lewat Pengaturan: periksa, kirim kode, lalu hapus.
///
/// Diuji lewat aplikasi utuh dari layar Pengaturan, mengikuti alasan yang sama dengan
/// `atur_password_dialog_test.dart`: yang paling mungkin salah adalah sambungan dialog ke
/// `authRepositoryProvider` yang sama dengan yang menggerakkan router. Satu hal yang
/// hanya bisa dibuktikan dengan cara ini: sesudah akunnya terhapus, tidak ada kode
/// navigasi di dialog, jadi layar berpindah ke layar masuk semata-mata karena sesinya
/// berakhir.
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

  Future<FakeAuthRepository> bukaDialog(
    WidgetTester tester, {
    List<String> penghalang = const [],
  }) async {
    final authRepo = FakeAuthRepository(userAwal: SeedData.klien)
      ..penghalangPenghapusan = List.of(penghalang);
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
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    // Butir paling bawah di daftar Pengaturan.
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Hapus Akun'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ListTile, 'Hapus Akun'));
    await tester.pumpAndSettle();

    return authRepo;
  }

  Finder tombolHapus() => find.widgetWithText(FilledButton, 'Hapus akun');
  Finder tombolKirim() => find.widgetWithText(FilledButton, 'Kirim kode');

  testWidgets('butir Hapus Akun tidak muncul untuk yang belum masuk', (
    tester,
  ) async {
    final authRepo = FakeAuthRepository.belumMasuk();
    addTearDown(authRepo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          authRepositoryProvider.overrideWith((ref) => authRepo),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MasukScreen), findsOneWidget);
    expect(find.text('Hapus Akun'), findsNothing);
  });

  testWidgets(
    'akun yang punya penghalang ditolak dengan alasannya, tanpa kode',
    (tester) async {
      await bukaDialog(
        tester,
        penghalang: ['Masih ada 2 pesanan yang sedang berjalan.'],
      );

      expect(find.text('Akunmu belum bisa dihapus saat ini:'), findsOneWidget);
      expect(find.textContaining('Masih ada 2 pesanan'), findsOneWidget);

      // Tidak ada jalan untuk meminta kode atau menghapus dari keadaan ini.
      expect(tombolKirim(), findsNothing);
      expect(tombolHapus(), findsNothing);
      expect(find.text('Tutup'), findsOneWidget);
    },
  );

  testWidgets('kirim kode mati sampai persetujuan dicentang', (tester) async {
    await bukaDialog(tester);

    expect(tester.widget<FilledButton>(tombolKirim()).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(tombolKirim()).onPressed, isNotNull);
  });

  testWidgets('alur lengkap: akun terhapus dan layar pindah ke layar masuk', (
    tester,
  ) async {
    final authRepo = await bukaDialog(tester);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(tombolKirim());
    await tester.pumpAndSettle();

    // Kode dikirim ke nomor akun yang sedang masuk, bukan nomor yang diketik.
    final kode = authRepo.kodeUntuk(SeedData.klien.noHp);
    expect(kode, isNotNull);

    await tester.enterText(find.byType(TextFormField), kode!);
    await tester.tap(tombolHapus());
    await tester.pumpAndSettle();

    expect(authRepo.userAktif, isNull);
    // Sesinya berakhir, dan hanya itu yang memindahkan layar.
    expect(find.byType(MasukScreen), findsOneWidget);
    expect(find.text('Akunmu sudah dihapus.'), findsOneWidget);
  });

  testWidgets('kode salah menampilkan galat dan akun tetap ada', (
    tester,
  ) async {
    final authRepo = await bukaDialog(tester);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(tombolKirim());
    await tester.pumpAndSettle();

    final benar = authRepo.kodeUntuk(SeedData.klien.noHp)!;
    final salah = benar == '000000' ? '111111' : '000000';

    await tester.enterText(find.byType(TextFormField), salah);
    await tester.tap(tombolHapus());
    await tester.pumpAndSettle();

    expect(find.textContaining('Kode salah'), findsOneWidget);
    expect(authRepo.userAktif, isNotNull);
    expect(find.byType(MasukScreen), findsNothing);
  });

  testWidgets(
    'server menolak di langkah akhir karena keadaan berubah: alasannya tampil, akun tetap ada',
    (tester) async {
      final authRepo = await bukaDialog(tester);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(tombolKirim());
      await tester.pumpAndSettle();

      // Di antara pemeriksaan awal dan penghapusan, ada pesanan baru yang berjalan.
      authRepo.penghalangPenghapusan = [
        'Masih ada 1 pesanan yang sedang berjalan.',
      ];

      await tester.enterText(
        find.byType(TextFormField),
        authRepo.kodeUntuk(SeedData.klien.noHp)!,
      );
      await tester.tap(tombolHapus());
      await tester.pumpAndSettle();

      expect(find.textContaining('Masih ada 1 pesanan'), findsOneWidget);
      expect(authRepo.userAktif, isNotNull);
    },
  );

  testWidgets('batal di langkah pertama tidak mengubah apa pun', (
    tester,
  ) async {
    final authRepo = await bukaDialog(tester);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.text('Hapus akun'), findsNothing);
    expect(authRepo.userAktif, isNotNull);
  });
}
