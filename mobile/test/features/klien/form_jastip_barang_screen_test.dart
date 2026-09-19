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

  Future<void> bukaForm(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sumberTiruan],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jastip Barang'));
    await tester.pumpAndSettle();
  }

  Finder kolom(int indeks) => find.byType(TextFormField).at(indeks);

  testWidgets('beranda membuka form saat Jastip Barang ditekan', (tester) async {
    await bukaForm(tester);

    expect(find.text('Barang apa yang dititip?'), findsOneWidget);
    expect(find.text('Diambil di mana?'), findsOneWidget);
    expect(find.text('Diantar ke mana?'), findsOneWidget);
    expect(find.text('Perkiraan jarak'), findsOneWidget);
  });

  testWidgets('kolom alamat pengambilan dan tujuan memiliki tombol pemilih peta', (
    tester,
  ) async {
    await bukaForm(tester);

    final tombolPeta = find.byIcon(Icons.map_outlined);
    // Ada dua tombol peta: satu untuk titik ambil, satu untuk titik tujuan
    expect(tombolPeta, findsNWidgets(2));
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

    // Isi kolom barang
    await tester.enterText(kolom(0), 'Buku catatan dan modul kuliah');
    // Kolom jarak adalah kolom ke-3 (indeks 3)
    await tester.enterText(kolom(3), '3');
    await tester.pumpAndSettle();

    expect(find.text('Rp 10.000'), findsOneWidget); // fee jasa titip barang
    expect(find.text('Rp 6.000'), findsOneWidget); // ongkos jarak 3 * 2.000
    expect(find.text('Rp 16.000'), findsNWidgets(2)); // ringkasan + bilah bawah
  });

  testWidgets('menolak kirim jika barang atau alamat belum diisi', (tester) async {
    await bukaForm(tester);

    // Cuma isi jarak
    await tester.enterText(kolom(3), '2');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buat Order'));
    await tester.pumpAndSettle();

    expect(find.text('Tulis dulu barang yang mau dititip'), findsOneWidget);
    expect(find.text('Alamat pengambilan wajib diisi'), findsOneWidget);
  });
}
