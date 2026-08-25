import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('aplikasi menampilkan nama user yang sedang masuk', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: UpnvjSuruhApp()));
    await tester.pumpAndSettle();

    expect(find.text('Halo, ${SeedData.klien.nama}'), findsOneWidget);
  });
}
