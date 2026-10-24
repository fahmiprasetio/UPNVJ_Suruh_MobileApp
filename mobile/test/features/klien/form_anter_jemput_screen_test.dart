import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/features/klien/order_jalur_a/form_anter_jemput_screen.dart';

import '../../support/tiruan.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  /// Layar cukup tinggi supaya seluruh isi form terbangun dalam satu viewport;
  /// tanpa ini ringkasan harga berada di luar layar dan tidak terjangkau tes.
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
    await tester.tap(find.text('Anter Jemput'));
    await tester.pumpAndSettle();
  }

  Finder kolom(int indeks) => find.byType(TextFormField).at(indeks);

  testWidgets('beranda membuka form saat Anter Jemput ditekan', (tester) async {
    await bukaForm(tester);

    expect(find.text('LOKASI JEMPUT'), findsOneWidget);
    expect(find.text('TUJUAN PENGANTARAN'), findsOneWidget);
  });

  testWidgets('harga belum ditampilkan sebelum jarak diisi', (tester) async {
    await bukaForm(tester);

    expect(find.text('Total'), findsNothing);
    expect(
      find.text('Pilih rute untuk melihat rincian tarif.'),
      findsOneWidget,
    );
  });

  testWidgets('harga muncul sendiri begitu jarak diisi', (tester) async {
    final contoh = Order(
      id: 'o-anjem-uji',
      kodeOrder: 'SRH-9902',
      klienId: SeedData.klien.id,
      namaKlien: SeedData.klien.nama,
      serviceType: ServiceType.anterJemput,
      status: OrderStatus.selesai,
      dibuatPada: DateTime(2026),
      alamatJemput: 'Kos Putri Melati',
      alamatTujuan: 'Gedung FIK',
      jarakKm: 3,
      harga: 11000,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sumberTiruan],
        child: MaterialApp(home: FormAnterJemputScreen(contoh: contoh)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rp 5.000'), findsOneWidget); // tarif dasar
    expect(find.text('Rp 6.000'), findsOneWidget); // ongkos jarak
    expect(find.text('Rp 11.000'), findsNWidgets(2)); // ringkasan + bilah bawah
  });

  testWidgets('koma diterima sebagai pemisah desimal', (tester) async {
    final contoh = Order(
      id: 'o-anjem-uji-2',
      kodeOrder: 'SRH-9903',
      klienId: SeedData.klien.id,
      namaKlien: SeedData.klien.nama,
      serviceType: ServiceType.anterJemput,
      status: OrderStatus.selesai,
      dibuatPada: DateTime(2026),
      alamatJemput: 'Kos Putri Melati',
      alamatTujuan: 'Gedung FIK',
      jarakKm: 2.5,
      harga: 10000,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sumberTiruan],
        child: MaterialApp(home: FormAnterJemputScreen(contoh: contoh)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jarak: 2,5 km'), findsOneWidget);
    expect(find.text('Rp 10.000'), findsNWidgets(2));
  });

  testWidgets('order tidak dibuat kalau alamat masih kosong', (tester) async {
    final contoh = Order(
      id: 'o-anjem-uji-3',
      kodeOrder: 'SRH-9904',
      klienId: SeedData.klien.id,
      namaKlien: SeedData.klien.nama,
      serviceType: ServiceType.anterJemput,
      status: OrderStatus.selesai,
      dibuatPada: DateTime(2026),
      alamatJemput: '',
      alamatTujuan: '',
      latitudeJemput: -6.2910,
      longitudeJemput: 106.7870,
      latitudeTujuan: -6.2898,
      longitudeTujuan: 106.7862,
      jarakKm: 3,
      harga: 11000,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sumberTiruan],
        child: MaterialApp(home: FormAnterJemputScreen(contoh: contoh)),
      ),
    );
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

    await tester.enterText(kolom(0), 'Kos Putri Melati');
    await tester.pump();
    await tester.tap(find.text('Kos Putri Melati Pondok Labu'));
    await tester.pump();

    await tester.enterText(kolom(1), 'Gedung FIK');
    await tester.pump();
    await tester.tap(find.text('Gedung FIK Kampus Pondok Labu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buat Order'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(RegExp(r'^Order SRH-\d+ dibuat$')),
      findsOneWidget,
    );

    // Order baru Jalur A langsung berstatus menunggu pembayaran.
    expect(find.text('Bayar Sekarang'), findsOneWidget);

    // Pekerjaannya sudah selesai, tidak boleh ada yang masih berputar.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  /// Yang diisi kolom jemput, bukan kolom tujuan, dan urutannya kebalikan dari
  /// jastip barang: di sini yang dijemput adalah dirinya sendiri, sedangkan di
  /// jastip yang diantar adalah dirinya sendiri. Menukar keduanya menghasilkan
  /// order yang berangkat ke alamat yang salah tanpa ada yang menyadarinya.
  testWidgets('alamat tersimpan mengisi sendiri kolom jemput', (tester) async {
    await bukaForm(tester);

    expect(
      tester.widget<TextFormField>(kolom(0)).controller?.text,
      SeedData.klien.alamat,
    );
    expect(tester.widget<TextFormField>(kolom(1)).controller?.text, isEmpty);
  });
}
