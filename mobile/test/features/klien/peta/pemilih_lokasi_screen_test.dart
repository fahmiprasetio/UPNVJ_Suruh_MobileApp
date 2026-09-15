import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:upnvj_suruh/features/klien/peta/pemilih_lokasi_screen.dart';

/// Lahir sesi 82 (dipakai ulang di Jastip Makanan sesi 85), belum punya satu
/// pun tes sendiri sampai sekarang (lihat catatan progres bagian 10).
/// Jaringan sungguhannya (`GeocodingOsm`) sudah diuji terpisah di
/// `core/peta/geocoding_osm_test.dart`; di sini yang diuji perilaku layarnya
/// sendiri: satu hasil langsung dipakai, banyak hasil ditampilkan sebagai
/// daftar kandidat (perbaikan sesi 85 supaya "UPN Veteran Jakarta" tidak
/// nyasar ke kampus lain), dan hasil pilihannya benar-benar keluar lewat
/// Navigator.pop.
void main() {
  Future<T> jalankan<T>(
    Future<T> Function() tugas,
    Future<http.Response> Function(http.Request) jawab,
  ) => http.runWithClient(tugas, () => MockClient(jawab));

  Widget bungkus() =>
      const MaterialApp(home: PemilihLokasiScreen(judul: 'Titik jemput'));

  Future<void> cari(WidgetTester tester, String kueri) async {
    await tester.enterText(find.byType(TextField), kueri);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.search));
    await tester.pumpAndSettle();
  }

  testWidgets('kueri kosong tidak memicu pencarian', (tester) async {
    await tester.pumpWidget(bungkus());
    await jalankan(
      () => cari(tester, '   '),
      (_) async => throw StateError('tidak boleh memanggil jaringan'),
    );

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('satu hasil langsung dipakai tanpa daftar kandidat', (
    tester,
  ) async {
    await tester.pumpWidget(bungkus());
    await jalankan(
      () => cari(tester, 'UPNVJ Pondok Labu'),
      (_) async => http.Response(
        '[{"display_name":"UPN Veteran Jakarta, Pondok Labu",'
        '"lat":"-6.2895","lon":"106.7853"}]',
        200,
      ),
    );

    expect(find.text('UPN Veteran Jakarta, Pondok Labu'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Pakai lokasi ini'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'lebih dari satu hasil menampilkan daftar kandidat, memilih salah satu mengisi lokasinya',
    (tester) async {
      await tester.pumpWidget(bungkus());
      await jalankan(
        () => cari(tester, 'UPN Veteran Jakarta'),
        (_) async => http.Response(
          '[{"display_name":"UPNVJ Pondok Labu","lat":"-6.2895",'
          '"lon":"106.7853"},'
          '{"display_name":"UPNVJ Limo","lat":"-6.35","lon":"106.78"}]',
          200,
        ),
      );

      expect(find.text('UPNVJ Pondok Labu'), findsOneWidget);
      expect(find.text('UPNVJ Limo'), findsOneWidget);
      // Belum ada yang jadi alamat terpilih (itu masih daftar kandidat).
      expect(find.text('Belum ada titik yang dipilih.'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'UPNVJ Limo'));
      await tester.pumpAndSettle();

      expect(find.text('UPNVJ Limo'), findsOneWidget);
      expect(find.text('UPNVJ Pondok Labu'), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    },
  );

  testWidgets('tidak ada hasil menampilkan pesan tidak ketemu', (
    tester,
  ) async {
    await tester.pumpWidget(bungkus());
    await jalankan(
      () => cari(tester, 'alamat yang tidak ada di mana pun'),
      (_) async => http.Response('[]', 200),
    );

    expect(find.textContaining('tidak ketemu'), findsOneWidget);
  });

  testWidgets(
    'menekan Pakai lokasi ini mengembalikan alamat dan posisinya lewat Navigator.pop',
    (tester) async {
      HasilPilihLokasi? hasil;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                hasil = await Navigator.of(context).push<HasilPilihLokasi>(
                  MaterialPageRoute(
                    builder: (_) => const PemilihLokasiScreen(),
                  ),
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await jalankan(
        () => cari(tester, 'UPNVJ'),
        (_) async => http.Response(
          '[{"display_name":"UPN Veteran Jakarta","lat":"-6.2895",'
          '"lon":"106.7853"}]',
          200,
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Pakai lokasi ini'));
      await tester.pumpAndSettle();

      expect(hasil, isNotNull);
      expect(hasil!.alamat, 'UPN Veteran Jakarta');
      expect(hasil!.posisi, const LatLng(-6.2895, 106.7853));
    },
  );
}
