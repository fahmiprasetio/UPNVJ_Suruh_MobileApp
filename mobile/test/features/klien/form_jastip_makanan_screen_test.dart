import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';

import '../../support/tiruan.dart';
import 'package:upnvj_suruh/core/config/tarif_config.dart';
import 'package:upnvj_suruh/domain/models/tarif.dart';
import 'package:upnvj_suruh/domain/pricing/kalkulator_tarif.dart';

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
    await tester.tap(find.text('Jastip Makanan'));
    await tester.pumpAndSettle();
  }

  Future<void> isiForm(
    WidgetTester tester, {
    String makanan = 'Ayam geprek level 2 + es teh manis, warung Bu Yati',
    String beli = 'Warung Bu Yati',
    String tujuan = 'Kos Melati kamar 7',
  }) async {
    final makananField = find.widgetWithText(
      TextFormField,
      'Tulis pesanan makanan & minuman...',
    );
    await tester.ensureVisible(makananField);
    await tester.enterText(makananField, makanan);
    final beliField = find.widgetWithText(
      TextFormField,
      'Nama warung atau kantin',
    );
    await tester.ensureVisible(beliField);
    await tester.enterText(beliField, beli);
    final tujuanField = find.widgetWithText(
      TextFormField,
      'Tempat antar / kos / kampus',
    );
    await tester.ensureVisible(tujuanField);
    await tester.enterText(tujuanField, tujuan);
    await tester.pumpAndSettle();
  }

  group('KalkulatorTarif.jastipMakanan', () {
    test('hanya fee tetap, tidak bergantung apa pun', () {
      final hasil = KalkulatorTarif.jastipMakanan(tarif: Tarif.bawaan);

      expect(hasil.total, TarifConfig.jastipMakananFee);
      expect(hasil.rincian, hasLength(1));
      expect(hasil.rincian.single.label, 'Ongkos jasa titip');
    });
  });

  testWidgets('total sudah tampil sejak layar dibuka, tanpa isian apa pun', (
    tester,
  ) async {
    // Beda dari Anter Jemput dan Jastip Barang: fee-nya tetap, tidak menunggu
    // jarak atau isian apa pun untuk bisa dihitung.
    await bukaForm(tester);

    expect(find.text('Ongkos Jasa Titip (Delivery)'), findsOneWidget);
    expect(find.text('Rp 5.000'), findsWidgets);
  });

  testWidgets('layar mengaku harga makanan belum termasuk', (tester) async {
    await bukaForm(tester);

    expect(
      find.text('Harga Makanan Dibayar Saat Serah Terima'),
      findsOneWidget,
    );
  });

  testWidgets('tidak ada kolom jarak di form ini', (tester) async {
    // Kalkulatornya tidak menerima jarak sama sekali (bagian 70), jadi
    // menampilkan kolomnya cuma menjanjikan sesuatu yang tidak dipakai.
    await bukaForm(tester);

    expect(find.text('Perkiraan jarak'), findsNothing);
  });

  testWidgets('pesanan yang ditulis asal ditolak', (tester) async {
    await bukaForm(tester);
    await isiForm(tester, makanan: 'ayam');

    await tester.tap(find.widgetWithText(FilledButton, 'Pesan Jastip'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Tulis lebih jelas, runner butuh nama makanan/minuman yang pasti',
      ),
      findsOneWidget,
    );
  });

  testWidgets('order jastip makanan dibuat dan membuka detailnya', (
    tester,
  ) async {
    await bukaForm(tester);
    await isiForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Pesan Jastip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('dibuat'), findsWidgets);
    expect(find.text('Menunggu Pembayaran'), findsWidgets);
    expect(
      find.text('Ayam geprek level 2 + es teh manis, warung Bu Yati'),
      findsOneWidget,
    );
  });

  testWidgets('alamat tersimpan mengisi sendiri kolom tujuan', (tester) async {
    await bukaForm(tester);

    final tujuanField = find.widgetWithText(
      TextFormField,
      'Tempat antar / kos / kampus',
    );
    await tester.ensureVisible(tujuanField);
    final tujuan = tester.widget<TextFormField>(tujuanField);
    expect(tujuan.controller?.text, SeedData.klien.alamat);
  });
}
