import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/features/klien/detail_order/detail_order_screen.dart'
    show uriTelepon;
import 'package:upnvj_suruh/features/klien/riwayat/riwayat_order_screen.dart'
    show cocokPencarianOrder;
import 'package:upnvj_suruh/providers/repository_providers.dart';

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

  /// Membuka riwayat dengan daftar order yang ditentukan tes, bukan data contoh bawaan.
  ///
  /// Dipakai untuk keadaan yang tidak ada di data contoh dan tidak bisa dibuat lewat
  /// tindakan pengguna, seperti bendera macet: yang menentukannya server, dan repository
  /// tiruan memang tidak menghitungnya sendiri.
  Future<void> bukaRiwayatDengan(WidgetTester tester, List<Order> orders) async {
    final repo = FakeOrderRepository(
      pemanggil: () => SeedData.klien.id,
      orderAwal: orders,
    );
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          orderRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pesanan'));
    await tester.pumpAndSettle();
  }

  Future<void> bukaRiwayat(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: [sumberTiruan], child: const UpnvjSuruhApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pesanan'));
    await tester.pumpAndSettle();
  }

  testWidgets('memisahkan order berjalan dari yang sudah selesai', (
    tester,
  ) async {
    await bukaRiwayat(tester);

    expect(find.text('Sedang berjalan (3)'), findsOneWidget);
    expect(find.text('Sudah selesai (1)'), findsOneWidget);
  });

  group('pencarian riwayat', () {
    testWidgets('kode order menyaring ke satu hasil saja', (tester) async {
      await bukaRiwayat(tester);

      await tester.enterText(
        find.byType(TextField),
        '0398',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('SRH-0398'), findsOneWidget);
      expect(find.textContaining('SRH-0411'), findsNothing);
      expect(find.text('Sedang berjalan (3)'), findsNothing);
    });

    testWidgets('nama layanan ikut dicocokkan, bukan cuma kode', (
      tester,
    ) async {
      await bukaRiwayat(tester);

      // SRH-0410 (Jastip Makanan) dan SRH-0398 (Jastip Barang) sama-sama
      // berawalan "Jastip".
      await tester.enterText(
        find.byType(TextField),
        'jastip',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('SRH-0410'), findsOneWidget);
      expect(find.textContaining('SRH-0398'), findsOneWidget);
      expect(find.textContaining('SRH-0411'), findsNothing);
      expect(find.textContaining('SRH-0409'), findsNothing);
    });

    testWidgets('kata kunci tanpa hasil menampilkan keterangannya', (
      tester,
    ) async {
      await bukaRiwayat(tester);

      await tester.enterText(
        find.byType(TextField),
        'tidak ada order seperti ini',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Tidak ada order yang cocok'),
        findsOneWidget,
      );
    });

    testWidgets('tombol hapus mengosongkan pencarian lagi', (tester) async {
      await bukaRiwayat(tester);

      await tester.enterText(
        find.byType(TextField),
        '0398',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('SRH-0411'), findsNothing);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.textContaining('SRH-0411'), findsOneWidget);
    });
  });

  test('cocokPencarianOrder cocok ke kode, layanan, dan catatan', () {
    final order = Order(
      id: 'o-1',
      kodeOrder: 'SRH-0412',
      klienId: 'k-1',
      namaKlien: 'Dina',
      serviceType: ServiceType.jastipBarang,
      status: OrderStatus.dikerjakan,
      dibuatPada: DateTime(2026, 1, 1),
      deskripsi: 'Ambil paket di Indomaret',
    );

    expect(cocokPencarianOrder(order, ''), isTrue);
    expect(cocokPencarianOrder(order, 'srh-0412'), isTrue);
    expect(cocokPencarianOrder(order, 'jastip barang'), isTrue);
    expect(cocokPencarianOrder(order, 'indomaret'), isTrue);
    expect(cocokPencarianOrder(order, 'tidak cocok'), isFalse);
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
        find.text('Menunggu runner yang tersedia mengajukan tawaran.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('nomor HP runner tunggal ditampilkan sebagai tautan tel', (
    tester,
  ) async {
    // SRH-0410 dikerjakan satu runner, SeedData.runner.
    await bukaRiwayat(tester);
    await tester.tap(find.textContaining('SRH-0410'));
    await tester.pumpAndSettle();

    final baris = find.textContaining(SeedData.runner.noHp);
    expect(baris, findsOneWidget);
    // Dibungkus InkWell, bukan Text polos, supaya jelas bisa ditekan. Tidak
    // benar-benar ditekan di sini: menekannya memanggil url_launcher lewat
    // kanal platform yang tidak ada di lingkungan tes.
    expect(
      find.ancestor(of: baris, matching: find.byType(InkWell)),
      findsOneWidget,
    );
  });

  test('uriTelepon membangun URI dengan skema tel', () {
    expect(uriTelepon('081234567891'), Uri.parse('tel:081234567891'));
  });

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

  testWidgets('order yang sudah dibayar menawarkan minta pembatalan, bukan batal', (
    tester,
  ) async {
    // SRH-0411 sudah dibayar. Membatalkannya menyangkut pengembalian uang, jadi
    // keputusannya milik admin. Yang penting kedua-duanya: tombol batal sendiri
    // memang tidak ada, DAN ada jalan menuju admin. Dulu yang berdiri di sini
    // cuma kalimatnya, dan kalimat tanpa jalan keluar adalah jalan buntu yang
    // sopan.
    await bukaRiwayat(tester);
    await tester.tap(find.textContaining('SRH-0411'));
    await tester.pumpAndSettle();

    expect(find.text('Batalkan order'), findsNothing);
    expect(find.text('Minta pembatalan'), findsOneWidget);
    expect(
      find.textContaining('tidak bisa dibatalkan sendiri'),
      findsOneWidget,
    );
  });

  testWidgets('permintaan pembatalan menuntut alasan sebelum bisa dikirim', (
    tester,
  ) async {
    await bukaRiwayat(tester);
    await tester.tap(find.textContaining('SRH-0411'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Minta pembatalan'));
    await tester.pumpAndSettle();

    final tombolKirim = find.widgetWithText(TextButton, 'Kirim permintaan');
    expect(tester.widget<TextButton>(tombolKirim).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Acaranya batal.');
    await tester.pump();

    expect(tester.widget<TextButton>(tombolKirim).onPressed, isNotNull);
  });

  /// Sesudah terkirim, yang berdiri di sana bukan tombol yang sama lagi. Klien yang
  /// masih melihat "Minta pembatalan" akan menekannya lagi dan mengira permintaannya
  /// tidak sampai.
  testWidgets('sesudah diminta, yang tampil keterangan menunggu jawaban', (
    tester,
  ) async {
    await bukaRiwayat(tester);
    await tester.tap(find.textContaining('SRH-0411'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Minta pembatalan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Acaranya batal.');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Kirim permintaan'));
    await tester.pumpAndSettle();

    expect(find.text('Minta pembatalan'), findsNothing);
    expect(find.textContaining('sudah sampai ke admin'), findsOneWidget);
  });

  /// Ordernya tetap berjalan selama permintaannya menunggu: runner yang memegangnya
  /// harus tetap mengerjakannya sampai admin memutuskan.
  testWidgets('meminta pembatalan tidak menggeser status ordernya', (
    tester,
  ) async {
    await bukaRiwayat(tester);
    await tester.tap(find.textContaining('SRH-0411'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Minta pembatalan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Acaranya batal.');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Kirim permintaan'));
    await tester.pumpAndSettle();

    expect(find.text('Order selesai. Terima kasih!'), findsNothing);
    expect(find.textContaining('sudah sampai ke admin'), findsOneWidget);
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

  testWidgets('order yang belum lama tetap memakai kalimat biasanya', (tester) async {
    await bukaRiwayat(tester);
    await tester.tap(find.textContaining('SRH-0411'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ordermu sedang disiarkan ke runner yang tersedia.'),
      findsOneWidget,
    );
    expect(find.textContaining('Belum ada runner yang mengambil'), findsNothing);
  });

  /// Order yang menganggur terlalu lama sekarang mengatakannya.
  ///
  /// Benderanya datang dari server, jadi tes ini memasangnya langsung. Yang diuji bukan
  /// perhitungannya (itu milik backend, dan diuji di sana), melainkan bahwa layar ini
  /// benar-benar mengganti kalimatnya dan menyebutkan jalan keluarnya.
  testWidgets('order yang lama tanpa runner mengatakannya, bukan bilang sedang disiarkan', (
    tester,
  ) async {
    final macet = SeedData.orderAwal().first.copyWith(macet: true);
    await bukaRiwayatDengan(tester, [macet]);

    await tester.tap(find.textContaining(macet.kodeOrder));
    await tester.pumpAndSettle();

    expect(find.textContaining('Belum ada runner yang mengambil'), findsOneWidget);
    expect(
      find.text('Ordermu sedang disiarkan ke runner yang tersedia.'),
      findsNothing,
    );
  });

  /// Dan jalan keluarnya memang ada di layar yang sama, beberapa sentimeter di bawahnya.
  /// Kalimat yang menyebut sesuatu yang tidak ada di layar lebih buruk daripada diam.
  testWidgets('kalimat macet menyebut jalan keluar yang benar-benar ada', (tester) async {
    final macet = SeedData.orderAwal().first.copyWith(macet: true);
    await bukaRiwayatDengan(tester, [macet]);

    await tester.tap(find.textContaining(macet.kodeOrder));
    await tester.pumpAndSettle();

    expect(find.text('Minta pembatalan'), findsOneWidget);
  });
}
