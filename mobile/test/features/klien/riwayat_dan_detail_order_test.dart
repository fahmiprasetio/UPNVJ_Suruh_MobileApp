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

  Future<void> bukaRiwayat(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [sumberTiruan],
        child: const UpnvjSuruhApp(),
      ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Order Saya'));
    await tester.pumpAndSettle();
  }

  testWidgets('memisahkan order berjalan dari yang sudah selesai', (
    tester,
  ) async {
    await bukaRiwayat(tester);

    expect(find.text('Sedang berjalan (3)'), findsOneWidget);
    expect(find.text('Sudah selesai (1)'), findsOneWidget);
  });

  testWidgets('order Jalur B tanpa harga ditandai menunggu penawaran', (
    tester,
  ) async {
    await bukaRiwayat(tester);

    expect(find.text('Harga menunggu penawaran'), findsOneWidget);
  });

  testWidgets('membuka detail order Jalur A menampilkan empat tahap', (
    tester,
  ) async {
    await bukaRiwayat(tester);

    await tester.tap(find.textContaining('SRH-0411'));
    await tester.pumpAndSettle();

    // Jalur A: tanpa tahap permintaan dan persetujuan penawaran.
    expect(find.text('Menunggu Pembayaran'), findsOneWidget);
    expect(find.text('Mencari Runner'), findsWidgets);
    expect(find.text('Dikerjakan'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('Permintaan'), findsNothing);
  });

  testWidgets('detail order Jalur B menampilkan kuota runner dan harga kosong', (
    tester,
  ) async {
    await bukaRiwayat(tester);

    await tester.tap(find.textContaining('SRH-0409'));
    await tester.pumpAndSettle();

    expect(find.text('0 dari 3 orang'), findsOneWidget);
    expect(find.text('Menunggu penawaran admin'), findsOneWidget);
    expect(
      find.text('Admin sedang membaca permintaanmu. Penawaran harga menyusul.'),
      findsOneWidget,
    );
  });

  testWidgets('detail order yang sudah selesai tidak menawarkan tindakan', (
    tester,
  ) async {
    await bukaRiwayat(tester);

    await tester.tap(find.textContaining('SRH-0398'));
    await tester.pumpAndSettle();

    expect(find.text('Order selesai. Terima kasih!'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Bayar Sekarang'), findsNothing);
  });
}
