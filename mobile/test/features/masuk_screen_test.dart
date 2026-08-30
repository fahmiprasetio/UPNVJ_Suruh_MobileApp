import 'dart:async';

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

/// Alur masuk diuji lewat aplikasi utuh, bukan layarnya sendirian, karena yang
/// paling mungkin salah bukan isi layarnya melainkan sambungannya: apakah
/// pengguna yang belum masuk benar-benar diantar ke sini, dan apakah ia benar-benar
/// pergi dari sini begitu sesinya ada.
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

  Future<FakeAuthRepository> bukaBelumMasuk(WidgetTester tester) async {
    final authRepo = FakeAuthRepository.belumMasuk();
    addTearDown(authRepo.dispose);
    final orderRepo = FakeOrderRepository();
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
    return authRepo;
  }

  Future<void> isi(WidgetTester tester, String label, String nilai) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), nilai);
    await tester.pump();
  }

  /// Menekan tombol lewat tulisannya.
  ///
  /// Sengaja bukan `widgetWithText(ButtonStyleButton, ...)`: `byType` mencocokkan
  /// tipe persis, sementara `ButtonStyleButton` abstrak, jadi `FilledButton` tidak
  /// pernah cocok dan finder-nya diam-diam kosong.
  Future<void> tekan(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('yang belum masuk diantar ke layar masuk', (tester) async {
    await bukaBelumMasuk(tester);

    expect(find.text('UPNVJ Suruh'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nomor HP'), findsOneWidget);
    expect(find.text('Kirim kode'), findsOneWidget);
  });

  testWidgets('nomor yang bentuknya salah ditolak sebelum menyentuh server', (
    tester,
  ) async {
    final repo = await bukaBelumMasuk(tester);

    await isi(tester, 'Nomor HP', '12345');
    await tekan(tester, 'Kirim kode');

    expect(find.textContaining('diawali 08'), findsOneWidget);
    // Tidak ada kode yang diminta, jadi tidak ada permintaan yang terkirim.
    expect(repo.kodeUntuk('12345'), isNull);
    expect(find.text('Kirim kode'), findsOneWidget);
  });

  testWidgets('nomor kosong ditolak', (tester) async {
    await bukaBelumMasuk(tester);

    await tekan(tester, 'Kirim kode');

    expect(find.text('Nomor HP belum diisi'), findsOneWidget);
  });

  testWidgets('nomor yang benar membawa ke langkah kode', (tester) async {
    final repo = await bukaBelumMasuk(tester);

    await isi(tester, 'Nomor HP', SeedData.klien.noHp);
    await tekan(tester, 'Kirim kode');

    expect(find.widgetWithText(TextFormField, 'Kode'), findsOneWidget);
    expect(find.textContaining(SeedData.klien.noHp), findsOneWidget);
    expect(repo.kodeUntuk(SeedData.klien.noHp), isNotNull);
  });

  testWidgets('kode yang benar memasukkan pengguna dan layar masuk ditinggalkan', (
    tester,
  ) async {
    final repo = await bukaBelumMasuk(tester);

    await isi(tester, 'Nomor HP', SeedData.klien.noHp);
    await tekan(tester, 'Kirim kode');
    await isi(tester, 'Kode', repo.kodeUntuk(SeedData.klien.noHp)!);
    await tekan(tester, 'Masuk');

    // Yang memindahkan layar adalah berubahnya sesi, bukan layar yang mendorong
    // dirinya sendiri.
    expect(find.widgetWithText(TextFormField, 'Kode'), findsNothing);
    expect(find.text('Kirim kode'), findsNothing);
    expect(repo.userAktif, SeedData.klien);
  });

  testWidgets('kode yang salah menampilkan galat dan tetap di langkah kode', (
    tester,
  ) async {
    final repo = await bukaBelumMasuk(tester);

    await isi(tester, 'Nomor HP', SeedData.klien.noHp);
    await tekan(tester, 'Kirim kode');
    final benar = repo.kodeUntuk(SeedData.klien.noHp)!;
    await isi(tester, 'Kode', benar == '000000' ? '111111' : '000000');
    await tekan(tester, 'Masuk');

    expect(find.text('Nomor atau kode tidak cocok'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Kode'), findsOneWidget);
    expect(repo.userAktif, isNull);
  });

  testWidgets('kode yang bentuknya salah ditolak sebelum dikirim', (tester) async {
    final repo = await bukaBelumMasuk(tester);

    await isi(tester, 'Nomor HP', SeedData.klien.noHp);
    await tekan(tester, 'Kirim kode');
    await isi(tester, 'Kode', '123');
    await tekan(tester, 'Masuk');

    expect(find.text('Kode terdiri dari 6 angka'), findsOneWidget);
    expect(repo.userAktif, isNull);
  });

  testWidgets('ganti nomor mengembalikan ke langkah nomor', (tester) async {
    await bukaBelumMasuk(tester);

    await isi(tester, 'Nomor HP', SeedData.klien.noHp);
    await tekan(tester, 'Kirim kode');
    await tekan(tester, 'Ganti nomor');

    expect(find.text('Kirim kode'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Kode'), findsNothing);
  });

  testWidgets('langkah kode menawarkan jalan keluar bagi yang belum punya akun', (
    tester,
  ) async {
    // Minta kode berakhir sama saja untuk nomor yang tidak terdaftar, jadi orang
    // yang belum punya akun baru tahu di langkah ini. Di sini pula ia harus diberi
    // jalan keluar, kalau tidak ia terjebak menunggu kode yang tidak akan datang.
    await bukaBelumMasuk(tester);

    await isi(tester, 'Nomor HP', '089999999999');
    await tekan(tester, 'Kirim kode');

    expect(find.widgetWithText(TextFormField, 'Kode'), findsOneWidget);
    expect(find.text('Daftar akun baru'), findsOneWidget);
  });

  group('daftar', () {
    testWidgets('mendaftar lalu langsung diantar ke langkah kode', (tester) async {
      final repo = await bukaBelumMasuk(tester);

      await tester.tap(find.text('Belum punya akun? Daftar'));
      await tester.pumpAndSettle();
      await isi(tester, 'Nama', 'Sari Utami');
      await isi(tester, 'Nomor HP', '081200000001');
      await tekan(tester, 'Daftar');

      // Nomornya tidak perlu diketik ulang untuk minta kode.
      expect(find.widgetWithText(TextFormField, 'Kode'), findsOneWidget);
      expect(repo.kodeUntuk('081200000001'), isNotNull);
    });

    testWidgets('akun hasil pendaftaran bisa langsung masuk sebagai klien', (
      tester,
    ) async {
      final repo = await bukaBelumMasuk(tester);

      await tester.tap(find.text('Belum punya akun? Daftar'));
      await tester.pumpAndSettle();
      await isi(tester, 'Nama', 'Sari Utami');
      await isi(tester, 'Nomor HP', '081200000001');
      await tekan(tester, 'Daftar');
      await isi(tester, 'Kode', repo.kodeUntuk('081200000001')!);
      await tekan(tester, 'Masuk');

      expect(repo.userAktif!.nama, 'Sari Utami');
      expect(repo.userAktif!.isRunner, isFalse);
      expect(repo.userAktif!.isAdmin, isFalse);
    });

    testWidgets('nama kosong ditolak', (tester) async {
      await bukaBelumMasuk(tester);

      await tester.tap(find.text('Belum punya akun? Daftar'));
      await tester.pumpAndSettle();
      await isi(tester, 'Nomor HP', '081200000001');
      await tekan(tester, 'Daftar');

      expect(find.text('Nama belum diisi'), findsOneWidget);
    });

    testWidgets('nomor yang sudah terdaftar tidak dibedakan di layar', (
      tester,
    ) async {
      // Dulu layar ini memunculkan "sudah terdaftar", dan kalimat itu adalah cara
      // memeriksa siapa saja yang punya akun: ketik nomor seseorang, dan layarnya
      // menyebutkan jawabannya. Sekarang jalannya sama persis dengan nomor baru,
      // yaitu lanjut ke langkah kode, jadi tidak ada yang bisa disimpulkan dari sini.
      final repo = await bukaBelumMasuk(tester);

      await tester.tap(find.text('Belum punya akun? Daftar'));
      await tester.pumpAndSettle();
      await isi(tester, 'Nama', 'Kembar');
      await isi(tester, 'Nomor HP', SeedData.klien.noHp);
      await tekan(tester, 'Daftar');

      expect(find.textContaining('sudah terdaftar'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Kode'), findsOneWidget);
      // Sampai di sini ia belum masuk: kodenya masih harus dibuktikan, dan kode itu
      // dikirim ke nomornya, bukan ke orang yang mengetiknya.
      expect(repo.userAktif, isNull);
    });

    testWidgets('yang nomornya sudah terdaftar masuk ke akunnya sendiri', (
      tester,
    ) async {
      // Sisi lain dari aturan yang sama, dan yang membuatnya tidak sekadar menutup
      // mulut layar: orang yang lupa bahwa ia sudah punya akun tetap sampai ke
      // akunnya, dengan nama lamanya, bukan nama yang baru saja ia ketik.
      final repo = await bukaBelumMasuk(tester);

      await tester.tap(find.text('Belum punya akun? Daftar'));
      await tester.pumpAndSettle();
      await isi(tester, 'Nama', 'Kembar');
      await isi(tester, 'Nomor HP', SeedData.klien.noHp);
      await tekan(tester, 'Daftar');

      await isi(tester, 'Kode', repo.kodeUntuk(SeedData.klien.noHp)!);
      await tekan(tester, 'Masuk');

      expect(repo.userAktif?.nama, SeedData.klien.nama);
    });

    testWidgets('sudah punya akun mengembalikan ke langkah nomor', (tester) async {
      await bukaBelumMasuk(tester);

      await tester.tap(find.text('Belum punya akun? Daftar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sudah punya akun? Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Kirim kode'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nama'), findsNothing);
    });
  });

  testWidgets('keluar mengembalikan pengguna ke layar masuk', (tester) async {
    // Sisi lain dari pengalihan yang sama. Tanpa router yang menyimak sesi, layar
    // dalam tetap terbuka setelah pengguna keluar.
    final authRepo = FakeAuthRepository();
    addTearDown(authRepo.dispose);
    final orderRepo = FakeOrderRepository();
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
    expect(find.text('Kirim kode'), findsNothing);

    // Tidak di-await di sini. Timer di dalamnya baru berjalan saat pengujinya
    // memompa frame, jadi menunggunya lebih dulu akan menggantung selamanya.
    unawaited(authRepo.keluar());
    // Jamnya dimajukan sendiri. `pumpAndSettle` berhenti begitu tidak ada frame
    // terjadwal, dan layar yang diam tidak menjadwalkan apa pun, jadi jeda di
    // dalam `keluar` tidak akan pernah lewat kalau cuma mengandalkan itu.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Kirim kode'), findsOneWidget);
  });
}
