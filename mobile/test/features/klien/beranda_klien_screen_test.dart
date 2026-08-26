import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/service_catalog.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Future<void> bukaBeranda(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: UpnvjSuruhApp()));
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

  testWidgets('layanan yang layarnya belum ada memberi tahu apa adanya', (
    tester,
  ) async {
    await bukaBeranda(tester);

    // Tinggal Jastip Makanan yang belum punya layar, karena bentuk formnya
    // menunggu keputusan mitra soal harga barang (bagian 14.7a).
    await tester.tap(find.text('Jastip Makanan'));
    await tester.pump();

    expect(
      find.text('Jastip Makanan belum dibuat, menyusul.'),
      findsOneWidget,
    );
  });
}
