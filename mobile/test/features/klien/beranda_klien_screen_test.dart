import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';

import '../../support/tiruan.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/service_catalog.dart';
import 'package:upnvj_suruh/features/klien/beranda/widgets/kartu_layanan.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    // Beranda satu kolom yang menggulung, dan pintu keduanya memang duduk di
    // bawah petak layanan. Pada layar tes bawaan yang cuma 600 piksel, pintu itu
    // ada di pohon widget tapi belum pernah dipasang, jadi tesnya akan gagal
    // untuk alasan yang tidak ada hubungannya dengan yang sedang diuji.
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

  Future<void> bukaBeranda(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [sumberTiruan],
        child: const UpnvjSuruhApp(),
      ));
    await tester.pumpAndSettle();
  }

  testWidgets('menyapa klien dengan nama depannya', (tester) async {
    await bukaBeranda(tester);

    expect(find.text('Halo, Dina'), findsOneWidget);
  });

  testWidgets('menampilkan seluruh layanan di katalog', (tester) async {
    await bukaBeranda(tester);

    for (final layanan in serviceCatalog) {
      expect(
        find.text(layanan.nama),
        findsOneWidget,
        reason: 'Layanan ${layanan.nama} tidak muncul di beranda',
      );
    }
  });

  testWidgets(
    'petak layanan tampil sesuai urutan dua baris rancangan sesi 84',
    (tester) async {
      await bukaBeranda(tester);

      final nama = tester
          .widgetList<KartuLayanan>(find.byType(KartuLayanan))
          .map((k) => k.layanan.nama)
          .toList();

      // Baris 1: Anter Jemput/Jastip Makanan/Bersih Kamar Mandi, baris 2:
      // Bersih-Bersih Kos/Bantu Pindah Kos/Jastip Barang -- lihat urutan
      // `serviceCatalog` dan `_BarisLayanan.sublist` di layarnya. Permintaan
      // Lain tidak ikut, ia `KartuPermintaanLain`, bukan `KartuLayanan`.
      expect(nama, [
        'Anter Jemput',
        'Jastip Makanan',
        'Bersih Kamar Mandi',
        'Bersih-Bersih Kos',
        'Bantu Pindah Kos',
        'Jastip Barang',
      ]);
    },
  );

  testWidgets('permintaan bebas dipisahkan sebagai pintu kedua', (
    tester,
  ) async {
    await bukaBeranda(tester);

    // Pemisah "atau" menandai batas antara Jalur A dan Jalur B.
    expect(find.text('atau'), findsOneWidget);

    final permintaanLain = serviceInfoOf(ServiceType.permintaanLain);
    expect(permintaanLain.track, OrderTrack.jalurB);
    expect(find.text(permintaanLain.deskripsi), findsOneWidget);
  });

  testWidgets('seluruh layanan berkatalog sudah punya layarnya, tidak ada yang ditandai segera', (
    tester,
  ) async {
    // Petak yang menjanjikan sesuatu lalu menjawab "menyusul" setelah ditekan
    // membuat pengguna menanggung penemuan yang seharusnya ditanggung layar.
    // Jastip Makanan adalah yang terakhir menyusul (rencana capstone bagian
    // 70); sesudahnya lencana ini seharusnya tidak muncul untuk siapa pun.
    await bukaBeranda(tester);

    expect(find.text('Segera'), findsNothing);
  });

  testWidgets('jastip makanan membuka form yang cuma menagih ongkos jasanya', (
    tester,
  ) async {
    await bukaBeranda(tester);

    await tester.tap(find.text('Jastip Makanan'));
    await tester.pumpAndSettle();

    expect(find.text('Makanan/minuman apa yang mau dititip?'), findsOneWidget);
    expect(find.text('Beli di mana?'), findsOneWidget);
  });
}
