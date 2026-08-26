import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/core/config/tarif_config.dart';
import 'package:upnvj_suruh/domain/pricing/kalkulator_tarif.dart';

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
    await tester.pumpWidget(const ProviderScope(child: UpnvjSuruhApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jastip Barang'));
    await tester.pumpAndSettle();
  }

  Future<void> isiForm(
    WidgetTester tester, {
    String barang = 'Ambil paket di Indomaret Pondok Labu atas nama Dina',
    String ambil = 'Indomaret Pondok Labu',
    String tujuan = 'Kos Melati kamar 7',
    String jarak = '2',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Barang apa yang dititip?'),
      barang,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Diambil di mana?'),
      ambil,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Diantar ke mana?'),
      tujuan,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Perkiraan jarak'),
      jarak,
    );
    await tester.pumpAndSettle();
  }

  group('KalkulatorTarif.jastipBarang', () {
    test('menjumlahkan ongkos jasa titip dengan ongkos jarak', () {
      final hasil = KalkulatorTarif.jastipBarang(jarakKm: 2);

      expect(hasil.total, 14000); // 10.000 + (2 x 2.000)
      expect(hasil.rincian.first.label, 'Ongkos jasa titip');
      expect(hasil.rincian.first.nominal, TarifConfig.jastipBarangFee);
      expect(hasil.rincian.last.label, 'Jarak 2 km');
    });

    test('harga barang tidak pernah ikut dihitung', () {
      // Rumusnya hanya punya dua komponen: jasa dan jarak. Kalau nanti mitra
      // memutuskan harga barang ikut ditagih, tes ini yang harus berubah
      // lebih dulu (bagian 14.7a).
      final hasil = KalkulatorTarif.jastipBarang(jarakKm: 5);

      expect(hasil.rincian, hasLength(2));
      expect(
        hasil.total,
        TarifConfig.jastipBarangFee + 5 * TarifConfig.jastipBarangTarifPerKm,
      );
    });

    test('jarak di atas batas ditahan di maksimal', () {
      final hasil = KalkulatorTarif.jastipBarang(jarakKm: 100);

      expect(hasil.rincian.last.label, 'Jarak 15 km');
    });
  });

  testWidgets('harga belum muncul sebelum jarak diisi', (tester) async {
    await bukaForm(tester);

    expect(
      find.text('Isi perkiraan jarak dulu, harganya langsung muncul di sini.'),
      findsOneWidget,
    );
  });

  testWidgets('harga terurai langsung muncul setelah jarak diisi', (
    tester,
  ) async {
    await bukaForm(tester);
    await isiForm(tester);

    expect(find.text('Ongkos jasa titip'), findsOneWidget);
    expect(find.text('Jarak 2 km'), findsOneWidget);
    expect(find.text('Rp 14.000'), findsWidgets);
  });

  testWidgets('layar mengaku harga barang belum termasuk', (tester) async {
    await bukaForm(tester);
    await isiForm(tester);

    expect(
      find.textContaining('Harga barangnya belum termasuk'),
      findsOneWidget,
    );
  });

  testWidgets('barang yang ditulis asal ditolak', (tester) async {
    await bukaForm(tester);
    await isiForm(tester, barang: 'paket');

    await tester.tap(find.widgetWithText(FilledButton, 'Buat Order'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tulis lebih jelas, runner tidak bisa menebak barangnya'),
      findsOneWidget,
    );
  });

  testWidgets('order jastip barang dibuat dan membuka detailnya', (
    tester,
  ) async {
    await bukaForm(tester);
    await isiForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Buat Order'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('dibuat'), findsWidgets);
    // Detail order menampilkan tahap pertama Jalur A.
    expect(find.text('Menunggu Pembayaran'), findsWidgets);
    expect(find.text('Ambil paket di Indomaret Pondok Labu atas nama Dina'),
        findsOneWidget);
  });
}
