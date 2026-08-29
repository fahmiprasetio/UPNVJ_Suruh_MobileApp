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

    // 50 milidetik, jauh lebih pendek dari 2,75 detik animasinya. Kalau
    // animasinya tidak benar-benar dilewati, pembukanya masih terpampang di
    // sini. Bingkai pertama menggambar pembuka dan menjadwalkan penandanya;
    // bingkai kedua menjalankan pengalihannya.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(PembukaScreen), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Nomor HP'), findsOneWidget);
  });

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
