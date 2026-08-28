import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';

import '../../support/tiruan.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  /// Layar cukup tinggi supaya seluruh isi form terbangun dalam satu viewport;
  /// tanpa ini ringkasan harga berada di luar layar dan tidak terjangkau tes.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> bukaForm(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [sumberTiruan],
        child: const UpnvjSuruhApp(),
      ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anter Jemput'));
    await tester.pumpAndSettle();
  }

  Finder kolom(int indeks) => find.byType(TextFormField).at(indeks);

  testWidgets('beranda membuka form saat Anter Jemput ditekan', (tester) async {
    await bukaForm(tester);

    expect(find.text('Dijemput di mana?'), findsOneWidget);
    expect(find.text('Diantar ke mana?'), findsOneWidget);
  });

  testWidgets('harga belum ditampilkan sebelum jarak diisi', (tester) async {
    await bukaForm(tester);

    expect(find.text('Total'), findsNothing);
    expect(
      find.text('Isi perkiraan jarak dulu, harganya langsung muncul di sini.'),
      findsOneWidget,
    );
  });

  testWidgets('harga muncul sendiri begitu jarak diisi', (tester) async {
    await bukaForm(tester);

    await tester.enterText(kolom(2), '3');
    await tester.pumpAndSettle();

    expect(find.text('Rp 5.000'), findsOneWidget); // tarif dasar
    expect(find.text('Rp 6.000'), findsOneWidget); // ongkos jarak
    expect(find.text('Rp 11.000'), findsNWidgets(2)); // ringkasan + bilah bawah
  });

  testWidgets('koma diterima sebagai pemisah desimal', (tester) async {
    await bukaForm(tester);

    await tester.enterText(kolom(2), '2,5');
    await tester.pumpAndSettle();

    expect(find.text('Jarak 2,5 km'), findsOneWidget);
    expect(find.text('Rp 10.000'), findsNWidgets(2));
  });

  testWidgets('order tidak dibuat kalau alamat masih kosong', (tester) async {
    await bukaForm(tester);

    await tester.enterText(kolom(2), '3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat Order'));
    await tester.pumpAndSettle();

    expect(find.text('Alamat jemput wajib diisi'), findsOneWidget);
    expect(find.text('Alamat tujuan wajib diisi'), findsOneWidget);
  });

  testWidgets('form lengkap membuat order lalu membuka detailnya', (
    tester,
  ) async {
    await bukaForm(tester);

    await tester.enterText(kolom(0), 'Kos Melati, Jl. Pondok Labu Raya No. 12');
    await tester.enterText(kolom(1), 'Gedung FIK UPNVJ');
    await tester.enterText(kolom(2), '3');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buat Order'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(RegExp(r'^Order SRH-\d+ dibuat$')),
      findsOneWidget,
    );

    // Order baru Jalur A langsung berstatus menunggu pembayaran.
    expect(find.text('Bayar Sekarang'), findsOneWidget);
    expect(find.text('Rp 11.000'), findsOneWidget);

    // Pekerjaannya sudah selesai, tidak boleh ada yang masih berputar.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
