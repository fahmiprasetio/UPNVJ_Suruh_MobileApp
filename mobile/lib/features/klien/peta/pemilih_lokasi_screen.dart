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

  /// Sampai lima kandidat dari pencarian terakhir, menunggu dipilih.
  ///
  /// Dulu hasil pertama langsung dipakai tanpa ditanya, dan itu yang membuat
  /// "UPN Veteran Jakarta" bisa nyasar ke kampus Limo padahal yang dimaksud
  /// Pondok Labu -- Nominatim memang mengembalikan lebih dari satu kandidat,
  /// cuma aplikasinya yang menebak buta kandidat teratas. Daftar ini dikosongkan
  /// begitu satu dipilih atau peta diketuk langsung.
  List<HasilPencarianAlamat> _kandidat = const [];

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
    final isTujuan = (widget.judul ?? '').toLowerCase().contains('tujuan');
    final warnaPin = isTujuan
        ? const Color(0xFFE53935)
        : const Color(0xFF00AA13);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00AA13),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.judul ?? 'Pilih lokasi di peta',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17.5,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pencarianController,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF2F6F3),
                      hintText: 'Cari alamat, kampus, kos, atau jalan...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF7A867D),
                        fontSize: 13.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF00AA13),
                        size: 22,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0EAE1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF00AA13),
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _cari(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF00AA13),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _sedangMencari ? null : _cari,
                  icon: _sedangMencari
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search_rounded),
                ),
              ],
            ),
          ),
          if (_kandidat.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.spasiSedang,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _kandidat.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final kandidat = _kandidat[index];
                    return ListTile(
                      leading: Icon(Icons.place_outlined, color: skema.primary),
                      title: Text(
                        kandidat.alamat,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _pilihKandidat(kandidat),
                    );
                  },
                ),
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
                    minZoom: 3,
                    maxZoom: 19,
                    onTap: (_, titik) => _pilihTitik(titik),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                      enableMultiFingerGestureRace: false,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.upnvjsuruh.mobile',
                      maxZoom: 19,
                      panBuffer: 1,
                      keepBuffer: 3,
                      tileDisplay: const TileDisplay.fadeIn(
                        duration: Duration(milliseconds: 150),
                      ),
                      tileUpdateTransformer:
                          TileUpdateTransformers.throttle(
                        const Duration(milliseconds: 100),
                      ),
                    ),
                    if (_posisi != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _posisi!,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.location_on_rounded,
                              color: warnaPin,
                              size: 44,
                              shadows: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Panduan ketuk peta jika belum ada posisi terpilih
                if (_posisi == null)
                  IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spasiSedang,
                        vertical: AppTheme.spasiKecil,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPil),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 16,
                            color: Color(0xFF00AA13),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Geser & ketuk peta untuk menentukan titik',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E2124),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: AppTheme.spasiSedang,
                  bottom: AppTheme.spasiSedang,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoomInPemilih',
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E2124),
                        elevation: 3,
                        onPressed: () {
                          final c = _mapController.camera;
                          _mapController.move(c.center, (c.zoom + 1).clamp(3.0, 19.0));
                        },
                        tooltip: 'Perbesar peta',
                        child: const Icon(Icons.add_rounded),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoomOutPemilih',
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E2124),
                        elevation: 3,
                        onPressed: () {
                          final c = _mapController.camera;
                          _mapController.move(c.center, (c.zoom - 1).clamp(3.0, 19.0));
                        },
                        tooltip: 'Perkecil peta',
                        child: const Icon(Icons.remove_rounded),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'lokasiSaatIni',
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF00AA13),
                        elevation: 3,
                        onPressed: _sedangCariLokasi ? null : _pakaiLokasiSaatIni,
                        tooltip: 'Pakai lokasi saat ini',
                        child: _sedangCariLokasi
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00AA13),
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              MediaQuery.of(context).padding.bottom + 14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: warnaPin,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOKASI TERPILIH ${isTujuan ? "(TUJUAN)" : "(JEMPUT)"}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00AA13),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _sedangMenerjemahkan
                                ? 'Membaca alamat dari peta...'
                                : (_alamat ??
                                      'Ketuk pada peta untuk memilih titik lokasi.'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E2124),
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00AA13),
                      disabledBackgroundColor: const Color(0xFFD6D6D6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _posisi == null || _sedangMenerjemahkan
                        ? null
                        : _pakaiLokasi,
                    child: const Text(
                      'Pakai Lokasi Ini',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
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
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Alamat tidak ketemu di peta gratis ini. Coba nama jalan atau '
              'patokan yang lebih umum, atau ketuk langsung titiknya di peta.',
            ),
          ),
        );
      return;
    }

    // Kandidat ditampilkan, bukan langsung dipakai -- lihat alasannya di
    // deklarasi `_kandidat`. Kalau cuma satu, tidak ada yang perlu dipilih.
    if (hasil.length == 1) {
      _pilihKandidat(hasil.first);
      return;
    }
    setState(() => _kandidat = hasil);
  }

  void _pilihKandidat(HasilPencarianAlamat kandidat) {
    setState(() {
      _posisi = kandidat.posisi;
      _alamat = kandidat.alamat;
      _kandidat = const [];
    });
    _mapController.move(kandidat.posisi, 16);
  }

  Future<void> _pilihTitik(LatLng titik) async {
    setState(() {
      _posisi = titik;
      _alamat = null;
      _kandidat = const [];
      _sedangMenerjemahkan = true;
    });

    final alamat = await GeocodingOsm.alamatDari(titik);
    if (!mounted) return;
    setState(() {
      _sedangMenerjemahkan = false;
      _alamat =
          alamat ??
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
      _beriTahu('Gagal mengambil lokasi. Pastikan GPS aktif dan coba lagi.');
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
    Navigator.of(
      context,
    ).pop(HasilPilihLokasi(alamat: _alamat!, posisi: _posisi!));
  }
}
