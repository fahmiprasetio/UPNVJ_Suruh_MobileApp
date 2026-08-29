import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/features/pembuka/pembuka_screen.dart';
import 'package:upnvj_suruh/features/pembuka/widgets/lencana_logo.dart';
import 'package:upnvj_suruh/features/pembuka/widgets/teks_melengkung.dart';
import 'package:upnvj_suruh/providers/pembuka_providers.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

/// Layar pembuka diuji lewat aplikasi utuh, bukan layarnya sendirian.
///
/// Yang paling mungkin salah bukan animasinya, melainkan gerbangnya: apakah ia
/// benar-benar layar pertama, apakah ia benar-benar bubar sendiri, dan apakah
/// selama ia hidup tidak ada layar lain yang menyelinap terbuka. Ketiganya cuma
/// terlihat kalau router ikut dijalankan.
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
  }) async {
    addTearDown(authRepo.dispose);
    final orderRepo = FakeOrderRepository();
    addTearDown(orderRepo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => authRepo),
          orderRepositoryProvider.overrideWith((ref) => orderRepo),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    // Sengaja bukan `pumpAndSettle`: satu bingkai saja, supaya yang terlihat
    // adalah keadaan aplikasi tepat setelah dibuka, sebelum animasinya jalan.
    await tester.pump();
  }

  testWidgets('layar pertama adalah pembuka, bukan beranda atau layar masuk', (
    tester,
  ) async {
    await buka(tester, authRepo: FakeAuthRepository.belumMasuk());

    expect(find.byType(PembukaScreen), findsOneWidget);
    expect(find.byType(LencanaLogo), findsOneWidget);
    expect(find.byType(TeksMelengkung), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nomor HP'), findsNothing);
  });

  testWidgets('tulisan melengkung terbaca pembaca layar', (tester) async {
    final pegangan = tester.ensureSemantics();
    await buka(tester, authRepo: FakeAuthRepository.belumMasuk());
    // Dimajukan melewati awal animasi. Selama lencananya masih tembus pandang,
    // seluruh isinya memang tidak punya simpul semantik, dan itu benar: yang
    // belum terlihat juga belum layak dibacakan.
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.bySemanticsLabel('UPNVJ SURUH'), findsOneWidget);
    pegangan.dispose();
  });

  testWidgets(
    'pembuka bubar sendiri, yang belum masuk diantar ke layar masuk',
    (tester) async {
      await buka(tester, authRepo: FakeAuthRepository.belumMasuk());
      await tester.pumpAndSettle();

      expect(find.byType(PembukaScreen), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Nomor HP'), findsOneWidget);
    },
  );

  testWidgets('yang sudah masuk diantar ke berandanya, bukan ke layar masuk', (
    tester,
  ) async {
    await buka(tester, authRepo: FakeAuthRepository(userAwal: SeedData.klien));
    await tester.pumpAndSettle();

    expect(find.byType(PembukaScreen), findsNothing);
    expect(find.text('Halo, Dina'), findsOneWidget);
  });

  testWidgets('animasi dilewati kalau perangkat mematikan animasi', (
    tester,
  ) async {
    final authRepo = FakeAuthRepository.belumMasuk();
    addTearDown(authRepo.dispose);
    final orderRepo = FakeOrderRepository();
    addTearDown(orderRepo.dispose);

    // Disetel di platform, bukan lewat widget [MediaQuery] di atas aplikasi.
    // `MaterialApp` memasang MediaQuery-nya sendiri dari view, jadi yang
    // dipasang di atasnya tidak pernah terbaca.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => authRepo),
          orderRepositoryProvider.overrideWith((ref) => orderRepo),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );

    // Total satu detik, jauh lebih pendek dari 2,1 detik gerakan dekoratifnya.
    // Kalau animasinya tidak benar-benar dilewati, pembukanya masih terpampang
    // di sini menunggu gerakan yang harusnya dilompati. Beberapa bingkai kecil,
    // bukan satu bingkai besar: menunggu `kesiapanSesiProvider` lewat Riverpod
    // butuh beberapa putaran microtask dan bingkai berturut-turut sebelum
    // `Future`-nya benar-benar selesai, dan `pump` cuma memajukan satu bingkai
    // per panggilan.
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(PembukaScreen), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Nomor HP'), findsOneWidget);
  });

  testWidgets(
    'lencana tetap utuh menunggu sesi, tidak memudar sebelum waktunya',
    (tester) async {
      // Sebelumnya, gerakan dekoratif dan pudarnya adalah satu pengendali yang
      // sama, jadi begitu waktunya habis lencananya memudar tanpa peduli apakah
      // sesi sudah selesai dipulihkan dari server. Tes ini membuktikan
      // lencananya sekarang menunggu, bukan memudar begitu gerakan dekoratifnya
      // selesai di 2,1 detik: sesi ini sengaja tidak pernah diselesaikan sama
      // sekali, jadi kalau lencananya sudah memudar di sini, itu berarti
      // penantiannya diam-diam diabaikan.
      final siap = Completer<void>();
      addTearDown(() {
        // Completer yang tidak pernah diselesaikan tetap harus ditutup,
        // supaya provider yang menunggunya tidak mengeluh "future belum
        // selesai" begitu tes ini berakhir.
        if (!siap.isCompleted) siap.complete();
      });
      final authRepo = FakeAuthRepository.belumMasuk();
      addTearDown(authRepo.dispose);
      final orderRepo = FakeOrderRepository();
      addTearDown(orderRepo.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => authRepo),
            orderRepositoryProvider.overrideWith((ref) => orderRepo),
            kesiapanSesiProvider.overrideWith((ref) => siap.future),
          ],
          child: const UpnvjSuruhApp(),
        ),
      );

      // Melewati waktu gerakan dekoratifnya (2,1 detik) tapi masih di dalam
      // batas tunggu sesi (3 detik). Sesinya belum siap sama sekali, jadi
      // layar pembuka harus tetap di sana dan lencananya tidak boleh sedang
      // memudar.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2500));

      expect(find.byType(PembukaScreen), findsOneWidget);
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1.0);

      // Diselesaikan dan dihabiskan di sini, bukan diserahkan ke `addTearDown`.
      // Timer di balik `Future.timeout` (batas tunggu sesinya) masih menyala
      // pada titik ini, dan `flutter_test` mengeluh kalau widget tree dibuang
      // sementara masih ada timer yang menyala.
      siap.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'penantian sesi punya batas, tidak menunggu selamanya',
    (tester) async {
      // Panggilan jaringan yang tidak pernah dijawab tidak boleh menahan layar
      // pertama selamanya. Sesinya di sini sengaja tidak pernah diselesaikan,
      // jadi kalau layar pembuka masih ada setelah batas tunggunya lewat, itu
      // berarti batasnya tidak sungguh-sungguh dipatuhi.
      final siap = Completer<void>();
      addTearDown(() {
        if (!siap.isCompleted) siap.complete();
      });
      final authRepo = FakeAuthRepository.belumMasuk();
      addTearDown(authRepo.dispose);
      final orderRepo = FakeOrderRepository();
      addTearDown(orderRepo.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => authRepo),
            orderRepositoryProvider.overrideWith((ref) => orderRepo),
            kesiapanSesiProvider.overrideWith((ref) => siap.future),
          ],
          child: const UpnvjSuruhApp(),
        ),
      );

      // Batas tunggu sesinya 3 detik, gerakan dekoratifnya 2,1 detik, pudarnya
      // 280 milidetik: total jalur terpanjang sekitar 3,3 detik. Dipompa
      // sampai 5 detik, cukup jauh melewati itu, tanpa sesinya pernah
      // diselesaikan. Bingkai kecil berturut-turut, bukan satu bingkai besar:
      // `Future.timeout` dan `Future.wait` butuh beberapa putaran microtask
      // dan bingkai sebelum benar-benar tuntas, dan satu `pump` besar cuma
      // memajukan satu bingkai.
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      expect(find.byType(PembukaScreen), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Nomor HP'), findsOneWidget);
    },
  );

  test('penanda pembuka cuma memberi kabar sekali', () {
    final status = StatusPembuka();
    addTearDown(status.dispose);

    var kabar = 0;
    status.addListener(() => kabar++);

    expect(status.selesai, isFalse);
    status.tandaiSelesai();
    status.tandaiSelesai();

    expect(status.selesai, isTrue);
    expect(kabar, 1);
  });
}
