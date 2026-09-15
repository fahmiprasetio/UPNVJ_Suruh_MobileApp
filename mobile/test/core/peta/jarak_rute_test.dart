import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:upnvj_suruh/core/peta/jarak_rute.dart';

/// Cek jalur gagal JarakRuteOsrm: server rute tak terjangkau, jawaban bukan
/// 200, dan jawaban "tidak ada rute" harus sama-sama menjawab null supaya
/// pemanggil (form Anter Jemput) meminta jarak diisi manual, bukan diam-diam
/// jatuh balik ke garis lurus (jebakan nomor 27 di catatan progres).
void main() {
  const dari = LatLng(-6.2895, 106.7853);
  const ke = LatLng(-6.3, 106.8);

  group('JarakRuteOsrm.kilometer', () {
    test('server tak terjangkau menjawab null, bukan melempar', () async {
      final hasil = await http.runWithClient(
        () => JarakRuteOsrm.kilometer(dari, ke),
        () => MockClient((_) async => throw Exception('jaringan mati')),
      );
      expect(hasil, isNull);
    });

    test('jawaban bukan 200 menjawab null', () async {
      final hasil = await http.runWithClient(
        () => JarakRuteOsrm.kilometer(dari, ke),
        () => MockClient((_) async => http.Response('error', 500)),
      );
      expect(hasil, isNull);
    });

    test('kode bukan Ok (tidak ada jalan antara dua titik) menjawab null', () async {
      final hasil = await http.runWithClient(
        () => JarakRuteOsrm.kilometer(dari, ke),
        () => MockClient(
          (_) async => http.Response('{"code":"NoRoute"}', 200),
        ),
      );
      expect(hasil, isNull);
    });

    test('jawaban sukses menjawab jarak dalam kilometer', () async {
      final hasil = await http.runWithClient(
        () => JarakRuteOsrm.kilometer(dari, ke),
        () => MockClient((request) async {
          expect(request.url.host, 'router.project-osrm.org');
          return http.Response(
            '{"code":"Ok","routes":[{"distance":12345.0}]}',
            200,
          );
        }),
      );
      expect(hasil, 12.345);
    });
  });
}
