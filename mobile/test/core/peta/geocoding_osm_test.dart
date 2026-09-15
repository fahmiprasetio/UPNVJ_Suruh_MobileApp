import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:upnvj_suruh/core/peta/geocoding_osm.dart';

/// Cek jalur gagal GeocodingOsm: jaringan tak terjangkau dan jawaban bukan
/// 200 harus menjawab kosong/null, bukan melempar galat mentah ke pemanggil
/// (PemilihLokasiScreen). Sebelum tes ini, nol tes membuktikan itu -- lihat
/// catatan progres bagian 10, "yang paling berisiko diam-diam rusak".
void main() {
  group('GeocodingOsm.cari', () {
    test('kueri kosong tidak memanggil jaringan sama sekali', () async {
      final hasil = await http.runWithClient(
        () => GeocodingOsm.cari('   '),
        () => MockClient(
          (_) async => throw StateError('tidak boleh memanggil jaringan'),
        ),
      );
      expect(hasil, isEmpty);
    });

    test(
      'jaringan tak terjangkau menjawab daftar kosong, bukan melempar',
      () async {
        final hasil = await http.runWithClient(
          () => GeocodingOsm.cari('kos dekat kampus'),
          () => MockClient((_) async => throw Exception('jaringan mati')),
        );
        expect(hasil, isEmpty);
      },
    );

    test('jawaban bukan 200 menjawab daftar kosong', () async {
      final hasil = await http.runWithClient(
        () => GeocodingOsm.cari('kos dekat kampus'),
        () => MockClient((_) async => http.Response('error', 500)),
      );
      expect(hasil, isEmpty);
    });

    test('jawaban sukses diterjemahkan jadi daftar hasil', () async {
      final hasil = await http.runWithClient(
        () => GeocodingOsm.cari('UPNVJ'),
        () => MockClient((request) async {
          expect(request.url.host, 'nominatim.openstreetmap.org');
          expect(request.url.queryParameters['countrycodes'], 'id');
          return http.Response(
            '[{"display_name":"UPN Veteran Jakarta","lat":"-6.2895",'
            '"lon":"106.7853"}]',
            200,
          );
        }),
      );
      expect(hasil, hasLength(1));
      expect(hasil.single.alamat, 'UPN Veteran Jakarta');
      expect(hasil.single.posisi, const LatLng(-6.2895, 106.7853));
    });
  });

  group('GeocodingOsm.alamatDari', () {
    const titik = LatLng(-6.2895, 106.7853);

    test('jaringan tak terjangkau menjawab null, bukan melempar', () async {
      final hasil = await http.runWithClient(
        () => GeocodingOsm.alamatDari(titik),
        () => MockClient((_) async => throw Exception('jaringan mati')),
      );
      expect(hasil, isNull);
    });

    test('jawaban bukan 200 menjawab null', () async {
      final hasil = await http.runWithClient(
        () => GeocodingOsm.alamatDari(titik),
        () => MockClient((_) async => http.Response('error', 503)),
      );
      expect(hasil, isNull);
    });

    test('jawaban sukses menjawab nama alamatnya', () async {
      final hasil = await http.runWithClient(
        () => GeocodingOsm.alamatDari(titik),
        () => MockClient((request) async {
          expect(request.url.path, '/reverse');
          return http.Response('{"display_name":"Jalan RS Fatmawati"}', 200);
        }),
      );
      expect(hasil, 'Jalan RS Fatmawati');
    });
  });
}
