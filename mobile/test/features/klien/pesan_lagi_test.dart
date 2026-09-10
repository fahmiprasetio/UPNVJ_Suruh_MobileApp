import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/core/format/formatters.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

import '../../support/tiruan.dart';

/// "Pesan lagi": memesan ulang order lama tanpa mengetik ulang isinya.
///
/// Yang diuji di sini bukan bahwa tombolnya ada, melainkan tiga hal yang gampang
/// salah dan sunyi kalau salah: tombolnya cuma muncul untuk order yang memang
/// bisa diulang, isian yang tersalin adalah isian order itu (bukan alamat profil
/// yang biasanya mengisi form), dan jadwal order lama justru TIDAK ikut tersalin.
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

  Future<void> bukaRiwayat(WidgetTester tester, [List<Order>? orders]) async {
    final overrides = [sumberTiruan];

    if (orders != null) {
      final repo = FakeOrderRepository(
        pemanggil: () => SeedData.klien.id,
        orderAwal: orders,
      );
      addTearDown(repo.dispose);
      overrides.add(orderRepositoryProvider.overrideWith((ref) => repo));
    }

    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const UpnvjSuruhApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pesanan'));
    await tester.pumpAndSettle();
  }

  Order seed(String kode) =>
      SeedData.orderAwal().firstWhere((o) => o.kodeOrder == kode);

  /// Isi kolom yang sungguhan, dibaca dari controllernya.
  ///
  /// Bukan `find.text`: beberapa kolom di form ini memakai contoh isian sebagai
  /// `hintText`, dan hint dibangun sebagai `Text` yang berbunyi sama walaupun
  /// kolomnya kosong. `find.text` tidak bisa membedakan keduanya, jadi ia bisa
  /// lulus untuk form yang sama sekali tidak terisi.
  String isiKolom(WidgetTester tester, String label) =>
      tester.widget<TextField>(find.widgetWithText(TextField, label))
          .controller!
          .text;

  testWidgets('cuma order yang sudah kelar yang bisa dipesan lagi', (
    tester,
  ) async {
    await bukaRiwayat(tester);

    // Data contoh punya satu order selesai (SRH-0398) dan tiga yang berjalan.
    expect(find.text('Sudah selesai (1)'), findsOneWidget);
    expect(find.text('Pesan lagi'), findsOneWidget);
  });

  testWidgets('jastip makanan yang sudah kelar ikut menawarkan pesan lagi', (
    tester,
  ) async {
    // Jastip Makanan adalah yang terakhir menyusul punya form (rencana
    // capstone bagian 70). Sesudahnya seluruh layanan berkatalog seharusnya
    // ikut menawarkan tombol ini begitu ordernya kelar.
    await bukaRiwayat(tester, [
      seed('SRH-0410').copyWith(status: OrderStatus.selesai),
    ]);

    expect(find.text('Sudah selesai (1)'), findsOneWidget);
    expect(find.text('Pesan lagi'), findsOneWidget);
  });

  testWidgets('order batal ikut bisa dipesan lagi', (tester) async {
    await bukaRiwayat(tester, [
      seed('SRH-0398').copyWith(status: OrderStatus.batal),
    ]);

    expect(find.text('Pesan lagi'), findsOneWidget);
  });

  testWidgets('pesan lagi membuka form jastip barang yang sudah terisi', (
    tester,
  ) async {
    await bukaRiwayat(tester);

    await tester.tap(find.text('Pesan lagi'));
    await tester.pumpAndSettle();

    final lama = seed('SRH-0398');
    expect(
      isiKolom(tester, 'Barang apa yang dititip?'),
      lama.deskripsi,
    );
    expect(isiKolom(tester, 'Diambil di mana?'), lama.alamatJemput);
    expect(isiKolom(tester, 'Diantar ke mana?'), lama.alamatTujuan);
    expect(isiKolom(tester, 'Perkiraan jarak'), '1');

    // Jarak ikut terisi, jadi harganya langsung terhitung ulang tanpa satu pun
    // ketukan tambahan: ongkos jasa 10.000 + 1 km x 2.000.
    expect(find.text('Rp 12.000'), findsWidgets);
  });

  testWidgets('isian order lama menang atas alamat tersimpan di profil', (
    tester,
  ) async {
    await bukaRiwayat(tester);

    await tester.tap(find.text('Pesan lagi'));
    await tester.pumpAndSettle();

    // Form jastip barang yang dibuka dari nol mengisi kolom "Diantar ke mana?"
    // dengan alamat profil. Yang menekan "Pesan lagi" sedang meminta "yang
    // seperti kemarin", jadi alamat kemarinlah yang benar, walaupun alamat di
    // profilnya berbeda.
    expect(isiKolom(tester, 'Diantar ke mana?'), isNot(SeedData.klien.alamat));
    expect(isiKolom(tester, 'Diantar ke mana?'), seed('SRH-0398').alamatTujuan);
  });

  testWidgets('pesan lagi Jalur B menyalin isian, tapi tidak jadwal lamanya', (
    tester,
  ) async {
    final lama = seed('SRH-0409').copyWith(status: OrderStatus.selesai);
    await bukaRiwayat(tester, [lama]);

    await tester.tap(find.text('Pesan lagi'));
    await tester.pumpAndSettle();

    expect(isiKolom(tester, 'Ceritakan kebutuhanmu'), lama.deskripsi);
    expect(isiKolom(tester, 'Alamat'), lama.alamatTujuan);

    // Jadwal order lama sudah lewat, jadi menawarkannya kembali berarti
    // menawarkan satu-satunya nilai yang pasti salah.
    expect(find.text(formatJadwal(lama.jadwalMulai!)), findsNothing);
  });

  testWidgets('layar detail order yang sudah kelar juga menawarkan pesan lagi', (
    tester,
  ) async {
    await bukaRiwayat(tester);

    await tester.tap(find.textContaining('SRH-0398'));
    await tester.pumpAndSettle();

    expect(find.text('Pesan Lagi'), findsOneWidget);

    await tester.tap(find.text('Pesan Lagi'));
    await tester.pumpAndSettle();

    expect(isiKolom(tester, 'Diambil di mana?'), seed('SRH-0398').alamatJemput);
  });

  testWidgets('layar detail order yang masih berjalan tidak menawarkannya', (
    tester,
  ) async {
    await bukaRiwayat(tester);

    await tester.tap(find.textContaining('SRH-0411'));
    await tester.pumpAndSettle();

    expect(find.text('Pesan Lagi'), findsNothing);
  });

  testWidgets(
    'layar detail order jastip makanan yang sudah kelar ikut menawarkannya',
    (tester) async {
      await bukaRiwayat(tester, [
        seed('SRH-0410').copyWith(status: OrderStatus.selesai),
      ]);

      await tester.tap(find.textContaining('SRH-0410'));
      await tester.pumpAndSettle();

      expect(find.text('Pesan Lagi'), findsOneWidget);
    },
  );
}
