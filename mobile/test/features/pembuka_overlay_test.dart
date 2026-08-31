import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/features/auth/masuk_screen.dart';
import 'package:upnvj_suruh/features/klien/beranda/beranda_klien_screen.dart';
import 'package:upnvj_suruh/features/pembuka/pembuka_overlay.dart';
import 'package:upnvj_suruh/features/pembuka/widgets/lencana_logo.dart';
import 'package:upnvj_suruh/features/pembuka/widgets/teks_melengkung.dart';
import 'package:upnvj_suruh/providers/pembuka_providers.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

/// Layar pembuka diuji lewat aplikasi utuh, bukan widgetnya sendirian.
///
/// Yang paling mungkin salah bukan animasinya, melainkan hubungannya dengan
/// aplikasi di belakangnya: apakah halaman berikutnya benar-benar sudah dibangun
/// selagi pembuka masih menutupi (itu satu-satunya alasan tidak ada jeda putih),
/// apakah pembukanya benar-benar bubar sendiri, dan apakah penantiannya punya
/// batas. Ketiganya cuma terlihat kalau router ikut dijalankan.
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

  Future<void> buka(
    WidgetTester tester, {
    required FakeAuthRepository authRepo,
    Future<void>? kesiapan,
  }) async {
    addTearDown(authRepo.dispose);
    final orderRepo = FakeOrderRepository();
    addTearDown(orderRepo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => authRepo),
          orderRepositoryProvider.overrideWith((ref) => orderRepo),
          if (kesiapan != null)
            kesiapanSesiProvider.overrideWith((ref) => kesiapan),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    // Sengaja bukan `pumpAndSettle`: satu bingkai saja, supaya yang terlihat
    // adalah keadaan aplikasi tepat setelah dibuka, sebelum animasinya jalan.
    await tester.pump();
  }

  testWidgets('pembuka menutupi aplikasi sejak bingkai pertama', (
    tester,
  ) async {
    await buka(tester, authRepo: FakeAuthRepository.belumMasuk());

    expect(find.byType(PembukaOverlay), findsOneWidget);
    expect(find.byType(LencanaLogo), findsOneWidget);
    expect(find.byType(TeksMelengkung), findsOneWidget);
  });

  testWidgets(
    'halaman berikutnya sudah dibangun di belakang pembuka, bukan sesudahnya',
    (tester) async {
      // Ini kasus yang menjaga cacat "layar putih sekejap" tidak kembali.
      //
      // Dulu pembuka adalah rute tersendiri, jadi `MasukScreen` baru mulai
      // dibangun SETELAH pembukanya pergi, dan sepanjang pembangunan itu yang
      // terlihat cuma latar putih. Sekarang pembuka adalah lapisan di atas
      // aplikasi, jadi `MasukScreen` harus sudah ada di pohon widget sejak
      // bingkai pertama, tertutup, siap tersingkap tanpa jeda.
      //
      // Kalau kasus ini gagal, artinya seseorang mengembalikan pembuka menjadi
      // rute, dan jeda putihnya ikut kembali.
      await buka(tester, authRepo: FakeAuthRepository.belumMasuk());

      expect(find.byType(PembukaOverlay), findsOneWidget);
      expect(
        find.byType(MasukScreen, skipOffstage: false),
        findsOneWidget,
        reason:
            'layar berikutnya harus sudah dibangun di belakang pembuka, '
            'supaya mengangkat pembuka tidak menyisakan layar kosong',
      );
    },
  );

  testWidgets(
    'beranda juga sudah dibangun di belakang pembuka untuk yang sudah masuk',
    (tester) async {
      await buka(
        tester,
        authRepo: FakeAuthRepository(userAwal: SeedData.klien),
      );

      expect(find.byType(PembukaOverlay), findsOneWidget);
      expect(
        find.byType(BerandaKlienScreen, skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets('tulisan melengkung terbaca pembaca layar', (tester) async {
    final pegangan = tester.ensureSemantics();
    await buka(tester, authRepo: FakeAuthRepository.belumMasuk());

    expect(find.bySemanticsLabel('UPNVJ SURUH'), findsOneWidget);
    pegangan.dispose();
  });

  testWidgets('pembuka bubar sendiri, yang belum masuk melihat layar masuk', (
    tester,
  ) async {
    await buka(tester, authRepo: FakeAuthRepository.belumMasuk());
    await tester.pumpAndSettle();

    expect(find.byType(PembukaOverlay), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Nomor HP'), findsOneWidget);
  });

  testWidgets('yang sudah masuk melihat berandanya, bukan layar masuk', (
    tester,
  ) async {
    await buka(tester, authRepo: FakeAuthRepository(userAwal: SeedData.klien));
    await tester.pumpAndSettle();

    expect(find.byType(PembukaOverlay), findsNothing);
    expect(find.text('Halo, Dina'), findsOneWidget);
  });

  testWidgets('animasi dilewati kalau perangkat mematikan animasi', (
    tester,
  ) async {
    // Disetel di platform, bukan lewat widget [MediaQuery] di atas aplikasi.
    // `MaterialApp` memasang MediaQuery-nya sendiri dari view, jadi yang
    // dipasang di atasnya tidak pernah terbaca.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await buka(tester, authRepo: FakeAuthRepository.belumMasuk());

    // Total satu detik, jauh lebih pendek dari 2,1 detik gerakan dekoratifnya.
    // Kalau animasinya tidak benar-benar dilewati, pembukanya masih terpampang
    // di sini. Beberapa bingkai kecil, bukan satu bingkai besar: menunggu
    // `kesiapanSesiProvider` lewat Riverpod butuh beberapa putaran microtask dan
    // bingkai berturut-turut, dan `pump` cuma memajukan satu bingkai per
    // panggilan.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(PembukaOverlay), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Nomor HP'), findsOneWidget);
  });

  testWidgets('lencana tetap utuh menunggu sesi, tidak diangkat lebih awal', (
    tester,
  ) async {
    // Gerakan dekoratif dan pengangkatan lapisannya dua pengendali terpisah,
    // supaya lapisannya tidak diangkat cuma karena animasinya sudah habis
    // sementara sesinya belum selesai dipulihkan dari server. Sesi di sini
    // sengaja tidak pernah diselesaikan, jadi kalau lapisannya sudah mulai
    // memudar, artinya penantiannya diam-diam diabaikan.
    final siap = Completer<void>();
    addTearDown(() {
      if (!siap.isCompleted) siap.complete();
    });

    await buka(
      tester,
      authRepo: FakeAuthRepository.belumMasuk(),
      kesiapan: siap.future,
    );

    // Melewati waktu gerakan dekoratifnya (2,1 detik) tapi masih di dalam batas
    // tunggu sesi (3 detik).
    await tester.pump(const Duration(milliseconds: 2500));

    expect(find.byType(PembukaOverlay), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1.0);

    // Diselesaikan dan dihabiskan di sini, bukan diserahkan ke `addTearDown`.
    // Timer di balik batas tunggunya masih menyala pada titik ini, dan
    // `flutter_test` mengeluh kalau pohon widget dibuang selagi ada timer hidup.
    siap.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('penantian sesi punya batas, tidak menunggu selamanya', (
    tester,
  ) async {
    // Panggilan jaringan yang tidak pernah dijawab tidak boleh menahan layar
    // pertama selamanya. Di browser, timer bahkan ditahan selagi tab tidak
    // fokus, sehingga batas waktu permintaan API yang 20 detik itu terasa tidak
    // berujung sampai tab-nya diklik.
    final siap = Completer<void>();
    addTearDown(() {
      if (!siap.isCompleted) siap.complete();
    });

    await buka(
      tester,
      authRepo: FakeAuthRepository.belumMasuk(),
      kesiapan: siap.future,
    );

    // Batas tunggu sesinya 3 detik, jeda diamnya 1 detik, angkatnya 220
    // milidetik: jalur terpanjang sekitar 4,2 detik (gerakan dekoratifnya 2,1
    // detik sudah lewat sebelum batas tunggu sesi selesai, jadi tidak ikut
    // menambah). Dipompa sampai 6 detik tanpa sesinya pernah diselesaikan.
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.byType(PembukaOverlay), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Nomor HP'), findsOneWidget);
  });

  test('penanda pembuka sekali jalan, tidak bisa dibalik', () {
    final wadah = ProviderContainer();
    addTearDown(wadah.dispose);

    expect(wadah.read(statusPembukaProvider), isFalse);
    wadah.read(statusPembukaProvider.notifier).tandaiSelesai();
    expect(wadah.read(statusPembukaProvider), isTrue);
    wadah.read(statusPembukaProvider.notifier).tandaiSelesai();
    expect(wadah.read(statusPembukaProvider), isTrue);
  });
}
