import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/peta/geocoding_osm.dart';
import '../../../core/theme/app_theme.dart';

/// Titik pusat peta kalau belum ada apa pun untuk ditunjuk: kampus UPNVJ
/// Pondok Labu, bukan (0, 0) yang jatuh di tengah Samudra Atlantik.
const _posisiUpnvj = LatLng(-6.2895, 106.7853);

/// Yang dikembalikan layar ini: alamat manusiawi dan titiknya.
class HasilPilihLokasi {
  const HasilPilihLokasi({required this.alamat, required this.posisi});

  final String alamat;
  final LatLng posisi;
}

/// Pilih satu titik di peta, jadi jalan kedua di samping mengetik alamat.
///
/// Bukan pengganti kolom alamat teks bebas -- klien tetap boleh mengetik
/// seperti biasa, ini cuma jalan yang lebih akurat untuk yang mau
/// memakainya, dan menyumbang koordinat yang dipakai menghitung jarak
/// sungguhan lewat garis lurus antara titik jemput dan tujuan.
///
/// Dua jalan menuju satu titik: mengetik lalu menekan Cari, atau langsung
/// mengetuk peta. Yang kedua tidak mengembalikan nama, cuma koordinat,
/// jadi alamatnya diterjemahkan balik lewat [GeocodingOsm.alamatDari]
/// sebelum bisa dipakai -- tombol "Pakai lokasi ini" mati sampai
/// penerjemahan itu selesai.
class PemilihLokasiScreen extends StatefulWidget {
  const PemilihLokasiScreen({super.key, this.posisiAwal, this.judul});

  /// Titik awal kalau kolom yang memanggil sudah pernah dipakai memilih
  /// lokasi. `null` untuk peta yang mulai dari kampus.
  final LatLng? posisiAwal;

  /// Judul bilah atas, disesuaikan pemanggil ("Titik jemput", "Tujuan").
  final String? judul;

  @override
  State<PemilihLokasiScreen> createState() => _PemilihLokasiScreenState();
}

class _PemilihLokasiScreenState extends State<PemilihLokasiScreen> {
  final _mapController = MapController();
  final _pencarianController = TextEditingController();

  LatLng? _posisi;
  String? _alamat;
  bool _sedangMencari = false;
  bool _sedangMenerjemahkan = false;
  bool _sedangCariLokasi = false;

  @override
  void initState() {
    super.initState();
    _posisi = widget.posisiAwal;
  }

  @override
  void dispose() {
    _pencarianController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.judul ?? 'Pilih lokasi di peta')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spasiSedang),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pencarianController,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Cari alamat, misalnya nama kos atau jalan',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _cari(),
                  ),
                ),
                const SizedBox(width: AppTheme.spasiKecil),
                IconButton.filled(
                  onPressed: _sedangMencari ? null : _cari,
                  icon: _sedangMencari
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _posisi ?? _posisiUpnvj,
                    initialZoom: 15,
                    onTap: (_, titik) => _pilihTitik(titik),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.upnvjsuruh.mobile',
                    ),
                    if (_posisi != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _posisi!,
                            width: 40,
                            height: 40,
                            // Hijau, bukan warna galat bawaan Material: pin ini
                            // menandai titik yang dipilih, bukan sesuatu yang
                            // salah. Sistem dua warna aplikasi ini cuma kenal
                            // hijau (sudah benar) dan maroon (minta ditekan).
                            child: Icon(
                              Icons.location_on,
                              color: skema.primary,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Bukan hiasan: peta OSM tidak punya penanda pusat bawaan
                // seperti Google Maps, dan tanpa ini "ketuk untuk pilih"
                // tidak kelihatan sebagai ajakan sampai orangnya coba sendiri.
                if (_posisi == null)
                  IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spasiSedang,
                        vertical: AppTheme.spasiKecil,
                      ),
                      decoration: BoxDecoration(
                        color: skema.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPil,
                        ),
                      ),
                      child: Text(
                        'Ketuk peta untuk pilih titik',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                Positioned(
                  right: AppTheme.spasiSedang,
                  bottom: AppTheme.spasiSedang,
                  child: FloatingActionButton.small(
                    heroTag: 'lokasiSaatIni',
                    onPressed: _sedangCariLokasi ? null : _pakaiLokasiSaatIni,
                    tooltip: 'Pakai lokasi saat ini',
                    child: _sedangCariLokasi
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spasiSedang),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _sedangMenerjemahkan
                        ? 'Membaca nama alamat...'
                        : (_alamat ?? 'Belum ada titik yang dipilih.'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTheme.spasiSedang),
                  FilledButton(
                    onPressed: _posisi == null || _sedangMenerjemahkan
                        ? null
                        : _pakaiLokasi,
                    child: const Text('Pakai lokasi ini'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cari() async {
    final kueri = _pencarianController.text.trim();
    if (kueri.isEmpty) return;

    setState(() => _sedangMencari = true);
    final hasil = await GeocodingOsm.cari(kueri);
    if (!mounted) return;
    setState(() => _sedangMencari = false);

    if (hasil.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Alamat tidak ketemu.')));
      return;
    }

    final teratas = hasil.first;
    setState(() {
      _posisi = teratas.posisi;
      _alamat = teratas.alamat;
    });
    _mapController.move(teratas.posisi, 16);
  }

  Future<void> _pilihTitik(LatLng titik) async {
    setState(() {
      _posisi = titik;
      _alamat = null;
      _sedangMenerjemahkan = true;
    });

    final alamat = await GeocodingOsm.alamatDari(titik);
    if (!mounted) return;
    setState(() {
      _sedangMenerjemahkan = false;
      _alamat = alamat ??
          '${titik.latitude.toStringAsFixed(5)}, '
              '${titik.longitude.toStringAsFixed(5)}';
    });
  }

  /// Lokasi GPS perangkat, dari nol sampai pin terpasang di peta.
  ///
  /// Tiga gerbang berurutan: layanan lokasinya aktif atau tidak (GPS/mode
  /// lokasi HP), lalu izinnya (peramban atau sistem operasi yang bertanya ke
  /// pengguna -- aplikasi ini tidak bisa menyalakan izin itu sendiri, cuma
  /// memicu kotak dialognya lewat [Geolocator.requestPermission]), baru
  /// permintaan titiknya sendiri. Tiap gerbang yang gagal dijawab pesan yang
  /// bilang gerbang mana, bukan galat generik yang membuat orang menebak.
  Future<void> _pakaiLokasiSaatIni() async {
    setState(() => _sedangCariLokasi = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _beriTahu('Location service di HP/peramban belum aktif.');
        return;
      }

      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        // Inilah yang memunculkan kotak izin bawaan peramban/sistem operasi.
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) {
        _beriTahu('Izin lokasi ditolak, jadi tidak bisa dipakai otomatis.');
        return;
      }

      final posisi = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final titik = LatLng(posisi.latitude, posisi.longitude);
      _mapController.move(titik, 16);
      await _pilihTitik(titik);
    } catch (galat) {
      _beriTahu('Gagal mengambil lokasi: $galat');
    } finally {
      if (mounted) setState(() => _sedangCariLokasi = false);
    }
  }

  void _beriTahu(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  void _pakaiLokasi() {
    Navigator.of(context).pop(
      HasilPilihLokasi(alamat: _alamat!, posisi: _posisi!),
    );
  }
}
