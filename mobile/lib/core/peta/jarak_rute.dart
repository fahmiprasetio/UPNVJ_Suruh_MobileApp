import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Jarak tempuh jalan sungguhan antara dua titik, lewat OSRM (Open Source
/// Routing Machine) server demo publik -- gratis, tanpa API key, selaras
/// dengan seluruh dependensi luar proyek ini yang lain.
///
/// BUKAN garis lurus. Garis lurus mengabaikan jalan sungguhan -- jalan
/// memutar, jalan satu arah, sungai di antara dua titik -- dan runner tidak
/// bisa terbang lurus dari titik jemput ke tujuan. Profil `driving` dipakai
/// sebagai perkiraan jalan roda dua/empat; server demo ini tidak punya
/// profil motor tersendiri.
class JarakRuteOsrm {
  const JarakRuteOsrm._();

  /// `null` kalau server rute tidak terjangkau atau tidak menemukan jalan
  /// antara dua titiknya. Pemanggil wajib menjawabnya dengan meminta jarak
  /// diisi manual, bukan diam-diam jatuh balik ke garis lurus -- itu
  /// persis kesalahan yang mau dihindari dengan memakai rute sungguhan.
  static Future<double?> kilometer(LatLng dari, LatLng ke) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/'
          '${dari.longitude},${dari.latitude};'
          '${ke.longitude},${ke.latitude}',
      {'overview': 'false', 'alternatives': 'false', 'steps': 'false'},
    );

    try {
      final jawaban = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (jawaban.statusCode != 200) return null;

      final isi = jsonDecode(jawaban.body) as Map<String, dynamic>;
      if (isi['code'] != 'Ok') return null;

      final rute =
          (isi['routes'] as List<dynamic>).first as Map<String, dynamic>;
      return (rute['distance'] as num) / 1000;
    } catch (_) {
      return null;
    }
  }
}
