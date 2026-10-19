import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Satu hasil pencarian alamat: namanya dan titiknya.
class HasilPencarianAlamat {
  const HasilPencarianAlamat({required this.alamat, required this.posisi});

  final String alamat;
  final LatLng posisi;
}

/// Pencarian dan pembalikan alamat lewat Nominatim (OpenStreetMap).
///
/// Gratis, tanpa API key -- selaras dengan seluruh dependensi luar aplikasi
/// ini yang lain (lihat alasan Firebase tanpa `google-services.json`).
/// Kebijakan pemakaiannya menuntut User-Agent yang jelas dan bukan trafik
/// tinggi, dan keduanya cocok untuk aplikasi kampus berskala kecil ini.
class GeocodingOsm {
  const GeocodingOsm._();

  static const _headers = {
    'User-Agent': 'UpnvjSuruh/1.0 (capstone UPNVJ, kontak: tim pengembang)',
  };

  static Uri _uri(String path, Map<String, String> kueri) => Uri.https(
    'nominatim.openstreetmap.org',
    path,
    {...kueri, 'format': 'json'},
  );

  /// Sampai lima alamat yang cocok dengan [kueri] teks bebas.
  ///
  /// Dibatasi ke Indonesia (`countrycodes=id`) supaya "Pondok Labu" tidak
  /// kalah oleh nama tempat yang sama di negara lain.
  ///
  /// `[]` juga kalau server tidak terjangkau sama sekali, bukan cuma kalau
  /// ia menjawab bukan 200 -- pemanggil (`PemilihLokasiScreen`) sudah
  /// menjawab daftar kosong dengan pesan "coba nama lain", jalur yang sama
  /// persis yang harus menjawab jaringan mati.
  static Future<List<HasilPencarianAlamat>> cari(String kueri) async {
    final bersih = kueri.trim();
    if (bersih.isEmpty) return const [];

    try {
      final jawaban = await http.get(
        _uri('/search', {'q': bersih, 'limit': '5', 'countrycodes': 'id'}),
        headers: _headers,
      );
      if (jawaban.statusCode == 200) {
        final isi = jsonDecode(jawaban.body) as List<dynamic>;
        if (isi.isNotEmpty) {
          return isi
              .map(
                (baris) => HasilPencarianAlamat(
                  alamat: baris['display_name'] as String,
                  posisi: LatLng(
                    double.parse(baris['lat'] as String),
                    double.parse(baris['lon'] as String),
                  ),
                ),
              )
              .toList();
        }
      }
    } catch (_) {
      // Nominatim bisa terhalang CORS di Flutter Web, lanjutkan ke fallback Photon
    }

    // Fallback: Photon Komoot (berbasis OpenStreetMap dengan dukungan CORS penuh di Web)
    try {
      final photonUri = Uri.https('photon.komoot.io', '/api/', {
        'q': bersih,
        'limit': '5',
      });
      final jawabanPhoton = await http.get(photonUri);
      if (jawabanPhoton.statusCode == 200) {
        final data = jsonDecode(jawabanPhoton.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        return features.map((f) {
          final props = f['properties'] as Map<String, dynamic>? ?? {};
          final geom = f['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geom['coordinates'] as List<dynamic>? ?? [0.0, 0.0];
          final nama = props['name'] as String? ?? '';
          final jalan = props['street'] as String?;
          final kota = props['city'] as String? ?? props['district'] as String?;
          final bagian = [
            nama,
            if (jalan != null && jalan != nama) jalan,
            ?kota,
          ];
          final label = bagian.where((s) => s.isNotEmpty).join(', ');
          return HasilPencarianAlamat(
            alamat: label.isEmpty ? nama : label,
            posisi: LatLng(
              (coords[1] as num).toDouble(),
              (coords[0] as num).toDouble(),
            ),
          );
        }).toList();
      }
    } catch (_) {
      return const [];
    }

    return const [];
  }

  /// Alamat manusiawi untuk satu [titik], `null` kalau gagal diterjemahkan.
  ///
  /// Dipakai setelah pengguna mengetuk peta langsung, karena titik dari
  /// ketukan cuma berupa koordinat tanpa nama.
  static Future<String?> alamatDari(LatLng titik) async {
    try {
      final jawaban = await http.get(
        _uri('/reverse', {
          'lat': '${titik.latitude}',
          'lon': '${titik.longitude}',
        }),
        headers: _headers,
      );
      if (jawaban.statusCode == 200) {
        final isi = jsonDecode(jawaban.body) as Map<String, dynamic>;
        return isi['display_name'] as String?;
      }
    } catch (_) {
      // Nominatim bisa terhalang CORS di Web
    }

    // Fallback: Photon Komoot reverse geocoding
    try {
      final photonUri = Uri.https('photon.komoot.io', '/reverse', {
        'lat': '${titik.latitude}',
        'lon': '${titik.longitude}',
      });
      final jawaban = await http.get(photonUri);
      if (jawaban.statusCode == 200) {
        final data = jsonDecode(jawaban.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          final props = features.first['properties'] as Map<String, dynamic>? ?? {};
          final nama = props['name'] as String? ?? '';
          final jalan = props['street'] as String?;
          final kota = props['city'] as String? ?? props['district'] as String?;
          final bagian = [
            nama,
            if (jalan != null && jalan != nama) jalan,
            ?kota,
          ];
          final label = bagian.where((s) => s.isNotEmpty).join(', ');
          return label.isEmpty ? nama : label;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
