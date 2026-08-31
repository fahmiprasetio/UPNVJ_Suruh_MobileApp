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

  Future<void> bukaRiwayat(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: [sumberTiruan], child: const UpnvjSuruhApp()),
    );
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

  testWidgets(
    'detail order Jalur B menampilkan kuota runner dan harga kosong',
    (tester) async {
      await bukaRiwayat(tester);

      await tester.tap(find.textContaining('SRH-0409'));
      await tester.pumpAndSettle();

      expect(find.text('0 dari 3 orang'), findsOneWidget);
      // Harga yang belum ada ditulis sebesar harga sungguhan di kepala layar,
      // bukan diringkas jadi baris terakhir di tabel rincian.
      expect(find.text('Harga menunggu penawaran'), findsOneWidget);
      expect(
        find.text(
          'Admin sedang membaca permintaanmu. Penawaran harga menyusul.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('order yang belum dibayar bisa dibatalkan sendiri', (
    tester,
  ) async {
    // SRH-0409 adalah permintaan Jalur B yang belum berharga, jadi belum
    // dibayar. Sebelum tombol ini ada, klien yang salah menulis permintaannya
    // tidak punya cara menutupnya sama sekali; ordernya menggantung selamanya
    // dan satu-satunya jalan keluar adalah mengabaikannya.
    await bukaRiwayat(tester);
    await tester.tap(find.textContaining('SRH-0409'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Batalkan order'));
    await tester.pumpAndSettle();
    expect(find.text('Batalkan order ini?'), findsOneWidget);

    // Dicari di dalam dialognya, karena tombol di halaman di belakangnya
    // bertuliskan sama persis dan keduanya masih ada di pohon widget.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Batalkan order'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order SRH-0409 dibatalkan.'), findsOneWidget);
    // Tetap di layar yang sama, karena ordernya masih ada, cuma berstatus
    // batal, dan linimasa di layar ini sudah tahu cara menggambarkannya.
    expect(find.text('Batal'), findsWidgets);
  });

  testWidgets('dialog pembatalan bisa ditolak, dan ordernya tetap hidup', (
    tester,
  ) async {
    await bukaRiwayat(tester);
    await tester.tap(find.textContaining('SRH-0409'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Batalkan order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jangan'));
    await tester.pumpAndSettle();

    // Tombolnya masih ada, artinya ordernya masih bisa dibatalkan, artinya ia
    // belum dibatalkan.
    expect(find.text('Batalkan order'), findsOneWidget);
    expect(find.text('Order SRH-0409 dibatalkan.'), findsNothing);
  });

  testWidgets('order yang sudah dibayar menjelaskan kenapa tidak ada tombol', (
    tester,
  ) async {
    // SRH-0411 sudah dibayar. Server menolak membatalkannya karena ada uang
    // yang harus kembali, dan menyembunyikan tombolnya begitu saja membuat
    // pembatalan terlihat kadang ada kadang tidak tanpa aturan yang bisa
    // ditebak.
    await bukaRiwayat(tester);
    await tester.tap(find.textContaining('SRH-0411'));
    await tester.pumpAndSettle();

    expect(find.text('Batalkan order'), findsNothing);
    expect(
      find.textContaining('tidak bisa dibatalkan sendiri'),
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
