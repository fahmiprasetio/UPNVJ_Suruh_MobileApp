import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/features/klien/order_jalur_a/form_jastip_barang_screen.dart';

import '../../support/tiruan.dart';

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

  Future<void> bukaForm(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: [sumberTiruan], child: const UpnvjSuruhApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jastip Barang'));
    await tester.pumpAndSettle();
  }

  testWidgets('beranda membuka form saat Jastip Barang ditekan', (
    tester,
  ) async {
    await bukaForm(tester);

    expect(find.text('Jastip Barang Kampus'), findsOneWidget);
    expect(find.text('BARANG YANG DITITIP'), findsOneWidget);
    expect(find.text('TITIK PENGAMBILAN'), findsOneWidget);
    expect(find.text('TITIK PENGANTARAN'), findsOneWidget);
    expect(find.text('Pilih Rute'), findsOneWidget);
  });

  testWidgets(
    'kolom alamat pengambilan dan tujuan memiliki tombol pemilih peta',
    (tester) async {
      await bukaForm(tester);

      final tombolPeta = find.byIcon(Icons.map_outlined);
      // Ada dua tombol peta: satu untuk titik ambil, satu untuk titik tujuan
      expect(tombolPeta, findsNWidgets(2));
    },
  );

  testWidgets('harga belum ditampilkan sebelum jarak diisi', (tester) async {
    await bukaForm(tester);

    expect(find.text('Pilih Rute'), findsOneWidget);
    expect(find.textContaining('Rp 16.000'), findsNothing);
  });

  testWidgets('harga muncul sendiri begitu jarak diisi', (tester) async {
    final contoh = Order(
      id: 'o-jastip-uji',
      kodeOrder: 'SRH-9901',
      klienId: SeedData.klien.id,
      namaKlien: SeedData.klien.nama,
      serviceType: ServiceType.jastipBarang,
      status: OrderStatus.selesai,
      dibuatPada: DateTime(2026),
      deskripsi: 'Buku catatan dan modul kuliah',
      alamatJemput: 'Toko Buku Kampus',
      alamatTujuan: SeedData.klien.alamat,
      jarakKm: 3,
      harga: 16000,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sumberTiruan],
        child: MaterialApp(home: FormJastipBarangScreen(contoh: contoh)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rp 10.000'), findsOneWidget); // fee jasa titip barang
    expect(find.text('Rp 6.000'), findsOneWidget); // ongkos jarak 3 * 2.000
    expect(find.text('Rp 16.000'), findsNWidgets(2)); // ringkasan + bilah bawah
  });

  testWidgets('menolak kirim jika barang atau alamat belum diisi', (
    tester,
  ) async {
    await bukaForm(tester);

    await tester.tap(find.text('Buat Order'));
    await tester.pumpAndSettle();

    expect(find.text('Tulis dulu barang yang mau dititip'), findsOneWidget);
    expect(find.text('Alamat pengambilan wajib diisi'), findsOneWidget);
  });
}
