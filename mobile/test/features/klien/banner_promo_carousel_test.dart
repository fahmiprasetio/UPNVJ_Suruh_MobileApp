import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/features/klien/beranda/widgets/banner_promo_carousel.dart';

import '../../support/tiruan.dart';

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

  Widget bungkusWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: child,
        ),
      ),
    );
  }

  testWidgets('menampilkan item banner promo pertama secara bawaan', (
    tester,
  ) async {
    await tester.pumpWidget(
      bungkusWidget(const BannerPromoCarousel()),
    );
    await tester.pumpAndSettle();

    expect(find.text('PROMO SPESIAL'), findsOneWidget);
    expect(find.text('Diskon Ongkir Rp 5.000'), findsOneWidget);
    expect(
      find.text('Pakai kode VJHEMAT untuk pesanan pertamamu di UPNVJ Suruh!'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);
  });

  testWidgets('dapat berpindah ke slide promo kedua melalui ketukan indikator atau geser', (
    tester,
  ) async {
    await tester.pumpWidget(
      bungkusWidget(const BannerPromoCarousel()),
    );
    await tester.pumpAndSettle();

    // Ketuk indikator kedua untuk berpindah ke slide kedua
    await tester.tap(find.byKey(const ValueKey('indikator_promo_1')));
    await tester.pumpAndSettle();

    expect(find.text('TIPS HEMAT KAMPUS'), findsOneWidget);
    expect(find.text('Titip Makan Bareng Teman'), findsOneWidget);
    expect(
      find.text('1 runner bisa bawa hingga 3 porsi pesanan sekaligus tanpa ongkir dobel.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
  });

  testWidgets('mengetuk slide pertama membuka dialog rincian voucher dan kode kupon', (
    tester,
  ) async {
    await tester.pumpWidget(
      bungkusWidget(const BannerPromoCarousel()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Diskon Ongkir Rp 5.000'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Voucher Pengguna Baru: VJHEMAT'), findsOneWidget);
    expect(find.text('VJHEMAT'), findsOneWidget);
    expect(find.text('Salin'), findsOneWidget);
    expect(find.text('Tutup'), findsOneWidget);

    // Tekan salin kode kupon
    await tester.tap(find.text('Salin'));
    await tester.pumpAndSettle();

    expect(find.text('Kode kupon VJHEMAT berhasil disalin!'), findsOneWidget);

    // Tekan tutup dialog
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('slide tips memiliki tombol aksi yang mengarahkan ke form layanan di beranda penuh', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sumberTiruan],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Berpindah ke slide kedua (jastip makanan) via indikator
    await tester.tap(find.byKey(const ValueKey('indikator_promo_1')));
    await tester.pumpAndSettle();

    // Ketuk slide kedua
    await tester.tap(find.text('Titip Makan Bareng Teman'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Pesan Jastip Makanan'), findsOneWidget);

    // Ketuk tombol aksi pada dialog
    await tester.tap(find.text('Pesan Jastip Makanan'));
    await tester.pumpAndSettle();

    // Membuka form jastip makanan
    expect(find.text('Makanan/minuman apa yang mau dititip?'), findsOneWidget);
  });

  testWidgets('menangani daftar promo kosong dengan aman', (tester) async {
    await tester.pumpWidget(
      bungkusWidget(const BannerPromoCarousel(daftarPromo: [])),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BannerPromoCarousel), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });
}
