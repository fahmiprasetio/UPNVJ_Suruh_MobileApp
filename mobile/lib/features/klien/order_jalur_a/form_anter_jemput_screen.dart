import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/api/idempotency_key.dart';
import '../../../core/config/batas_masukan.dart';
import '../../../core/format/formatters.dart';
import '../../../core/format/jarak.dart';
import '../../../core/peta/geocoding_osm.dart';
import '../../../core/peta/jarak_rute.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/pesan_kosong.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/models/tarif.dart';
import '../../../domain/pricing/kalkulator_tarif.dart';
import '../peta/pemilih_lokasi_screen.dart';

/// Model saran titik lokasi untuk autocomplete form anter jemput.
class LokasiKampusModel {
  const LokasiKampusModel({
    required this.nama,
    required this.kategori,
    required this.posisi,
    required this.ikon,
    this.sublabel,
    this.dariOsm = false,
  });

  final String nama;
  final String kategori;
  final LatLng posisi;
  final IconData ikon;
  final String? sublabel;
  final bool dariOsm;
}

/// Daftar titik kampus UPNVJ Pondok Labu, Kampus Limo, dan titik transit populer.
const List<LokasiKampusModel> _daftarLokasiKampus = [
  LokasiKampusModel(
    nama: 'Gedung Kuliah Bersama (GKB) UPNVJ',
    kategori: 'Kampus Pondok Labu',
    posisi: LatLng(-6.2895, 106.7853),
    ikon: Icons.apartment_rounded,
    sublabel: 'Gedung perkuliahan utama',
  ),
  LokasiKampusModel(
    nama: 'Perpustakaan Pusat UPNVJ',
    kategori: 'Kampus Pondok Labu',
    posisi: LatLng(-6.2890, 106.7850),
    ikon: Icons.local_library_rounded,
    sublabel: 'Gedung Perpustakaan & Laboratorium',
  ),
  LokasiKampusModel(
    nama: 'Kantin Vokasi, Gedung C UPNVJ',
    kategori: 'Kuliner Kampus',
    posisi: LatLng(-6.2901, 106.7858),
    ikon: Icons.restaurant_rounded,
    sublabel: 'Area pujasera & nongkrong mahasiswa',
  ),
  LokasiKampusModel(
    nama: 'Gedung FIK Kampus Pondok Labu',
    kategori: 'Kampus Pondok Labu',
    posisi: LatLng(-6.2898, 106.7862),
    ikon: Icons.computer_rounded,
    sublabel: 'Fakultas Ilmu Komputer',
  ),
  LokasiKampusModel(
    nama: 'Gedung Rektorat UPNVJ',
    kategori: 'Kampus Pondok Labu',
    posisi: LatLng(-6.2892, 106.7848),
    ikon: Icons.account_balance_rounded,
    sublabel: 'Gedung Rektorat & Tata Usaha',
  ),
  LokasiKampusModel(
    nama: 'Plaza Wardhana UPNVJ',
    kategori: 'Kampus Pondok Labu',
    posisi: LatLng(-6.2894, 106.7851),
    ikon: Icons.park_rounded,
    sublabel: 'Pusat kegiatan terbuka mahasiswa',
  ),
  LokasiKampusModel(
    nama: 'Gedung FEB UPNVJ',
    kategori: 'Kampus Pondok Labu',
    posisi: LatLng(-6.2896, 106.7855),
    ikon: Icons.business_rounded,
    sublabel: 'Fakultas Ekonomi dan Bisnis',
  ),
  LokasiKampusModel(
    nama: 'Gedung FISIP UPNVJ',
    kategori: 'Kampus Pondok Labu',
    posisi: LatLng(-6.2899, 106.7849),
    ikon: Icons.groups_rounded,
    sublabel: 'Fakultas Ilmu Sosial dan Ilmu Politik',
  ),
  LokasiKampusModel(
    nama: 'Gedung Fakultas Hukum UPNVJ',
    kategori: 'Kampus Pondok Labu',
    posisi: LatLng(-6.2903, 106.7852),
    ikon: Icons.gavel_rounded,
    sublabel: 'Gedung FH UPNVJ',
  ),
  LokasiKampusModel(
    nama: 'Kampus UPNVJ Limo - Gedung Wahidin',
    kategori: 'Kampus Limo',
    posisi: LatLng(-6.3475, 106.7868),
    ikon: Icons.school_rounded,
    sublabel: 'Fakultas Kedokteran & Teknik Limo',
  ),
  LokasiKampusModel(
    nama: 'Kantin Kampus Limo UPNVJ',
    kategori: 'Kuliner Kampus',
    posisi: LatLng(-6.3479, 106.7872),
    ikon: Icons.lunch_dining_rounded,
    sublabel: 'Area kantin mahasiswa Limo',
  ),
  LokasiKampusModel(
    nama: 'Halte Busway Kampus UPNVJ Pondok Labu',
    kategori: 'Transportasi',
    posisi: LatLng(-6.2885, 106.7865),
    ikon: Icons.directions_bus_rounded,
    sublabel: 'Pintu gerbang depan Jl. RS Fatmawati',
  ),
  LokasiKampusModel(
    nama: 'Stasiun MRT Fatmawati Indomaret',
    kategori: 'Transportasi',
    posisi: LatLng(-6.2926, 106.7938),
    ikon: Icons.subway_rounded,
    sublabel: 'Stasiun MRT terdekat',
  ),
  LokasiKampusModel(
    nama: 'Stasiun KRL Lenteng Agung',
    kategori: 'Transportasi',
    posisi: LatLng(-6.3315, 106.8347),
    ikon: Icons.train_rounded,
    sublabel: 'Stasiun Commuter Line transit',
  ),
  LokasiKampusModel(
    nama: 'Indomaret Pondok Labu Raya',
    kategori: 'Sekitar Kampus',
    posisi: LatLng(-6.2905, 106.7860),
    ikon: Icons.storefront_rounded,
    sublabel: 'Minimarket & titik temu favorit',
  ),
  LokasiKampusModel(
    nama: 'Kos Putri Melati Pondok Labu',
    kategori: 'Area Kos',
    posisi: LatLng(-6.2910, 106.7870),
    ikon: Icons.home_rounded,
    sublabel: 'Jl. Pondok Labu Raya No. 12',
  ),
  LokasiKampusModel(
    nama: 'Kos Cempaka Pondok Labu',
    kategori: 'Area Kos',
    posisi: LatLng(-6.2920, 106.7880),
    ikon: Icons.home_work_rounded,
    sublabel: 'Jl. Pondok Labu Raya No. 30',
  ),
];

/// Form Jalur A untuk Anter Jemput dengan desain modern, lega, dan autocomplete alamat bebas.
class FormAnterJemputScreen extends ConsumerStatefulWidget {
  const FormAnterJemputScreen({super.key, this.contoh});

  final Order? contoh;

  @override
  ConsumerState<FormAnterJemputScreen> createState() =>
      _FormAnterJemputScreenState();
}

class _FormAnterJemputScreenState extends ConsumerState<FormAnterJemputScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _idempotencyKey = buatIdempotencyKey();
  final _jemputController = TextEditingController();
  final _tujuanController = TextEditingController();
  final _jarakController = TextEditingController();
  final _catatanController = TextEditingController();

  final _focusJemput = FocusNode();
  final _focusTujuan = FocusNode();

  List<LokasiKampusModel> _saranJemput = [];
  List<LokasiKampusModel> _saranTujuan = [];

  bool _sedangMengirim = false;
  bool _sedangHitungRute = false;
  bool _sedangCariJemput = false;
  bool _sedangCariTujuan = false;

  Timer? _debounceJemput;
  Timer? _debounceTujuan;

  LatLng? _posisiJemput;
  LatLng? _posisiTujuan;

  @override
  void initState() {
    super.initState();

    final contoh = widget.contoh;
    if (contoh != null) {
      _jemputController.text = contoh.alamatJemput ?? '';
      _tujuanController.text = contoh.alamatTujuan ?? '';
      _jarakController.text = tulisJarak(contoh.jarakKm);
      _catatanController.text = contoh.deskripsi ?? '';
      return;
    }

    final alamat = ref.read(authRepositoryProvider).userAktif?.alamat;
    if (alamat != null && alamat.isNotEmpty) {
      _jemputController.text = alamat;
    }

    _focusJemput.addListener(() {
      if (!_focusJemput.hasFocus) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !_focusJemput.hasFocus) {
            setState(() => _saranJemput = []);
          }
        });
      }
    });

    _focusTujuan.addListener(() {
      if (!_focusTujuan.hasFocus) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !_focusTujuan.hasFocus) {
            setState(() => _saranTujuan = []);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceJemput?.cancel();
    _debounceTujuan?.cancel();
    _jemputController.dispose();
    _tujuanController.dispose();
    _jarakController.dispose();
    _catatanController.dispose();
    _focusJemput.dispose();
    _focusTujuan.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Pencarian Autocomplete Lokal Kampus + Fallback Geocoding OSM / Photon
  // -------------------------------------------------------------------------

  void _saringSaran(String kueri, {required bool untukJemput}) {
    final q = kueri.trim().toLowerCase();

    if (untukJemput) {
      _debounceJemput?.cancel();
    } else {
      _debounceTujuan?.cancel();
    }

    if (q.isEmpty) {
      final rekomendasiAwal = _daftarLokasiKampus.take(4).toList();
      setState(() {
        if (untukJemput) {
          _saranJemput = rekomendasiAwal;
          _sedangCariJemput = false;
        } else {
          _saranTujuan = rekomendasiAwal;
          _sedangCariTujuan = false;
        }
      });
      return;
    }

    // 1. Fast path: cari di daftar titik lokal kampus
    final hasilLokal = _daftarLokasiKampus.where((loc) {
      return loc.nama.toLowerCase().contains(q) ||
          loc.kategori.toLowerCase().contains(q) ||
          (loc.sublabel?.toLowerCase().contains(q) ?? false);
    }).take(4).toList();

    if (hasilLokal.isNotEmpty) {
      setState(() {
        if (untukJemput) {
          _saranJemput = hasilLokal;
          _sedangCariJemput = false;
        } else {
          _saranTujuan = hasilLokal;
          _sedangCariTujuan = false;
        }
      });
      return;
    }

    // 2. Alamat luar kampus (misal Lenteng Agung): debounce lalu cari ke OpenStreetMap
    setState(() {
      if (untukJemput) {
        _sedangCariJemput = true;
        _saranJemput = [];
      } else {
        _sedangCariTujuan = true;
        _saranTujuan = [];
      }
    });

    final timer = Timer(const Duration(milliseconds: 400), () async {
      final hasilOsm = await GeocodingOsm.cari(kueri.trim());
      if (!mounted) return;

      final saranOsm = hasilOsm
          .take(4)
          .map(
            (item) => LokasiKampusModel(
              nama: item.alamat,
              kategori: 'Alamat Peta',
              posisi: item.posisi,
              ikon: Icons.public_rounded,
              sublabel: 'Pencarian Peta OSM',
              dariOsm: true,
            ),
          )
          .toList();

      setState(() {
        if (untukJemput) {
          _saranJemput = saranOsm;
          _sedangCariJemput = false;
        } else {
          _saranTujuan = saranOsm;
          _sedangCariTujuan = false;
        }
      });
    });

    if (untukJemput) {
      _debounceJemput = timer;
    } else {
      _debounceTujuan = timer;
    }
  }

  void _pilihSaran(LokasiKampusModel item, {required bool untukJemput}) {
    setState(() {
      if (untukJemput) {
        _jemputController.text = item.nama;
        _posisiJemput = item.posisi;
        _saranJemput = [];
        _focusJemput.unfocus();
      } else {
        _tujuanController.text = item.nama;
        _posisiTujuan = item.posisi;
        _saranTujuan = [];
        _focusTujuan.unfocus();
      }
    });
    _hitungOtomatisJarak();
  }

  Future<void> _hitungOtomatisJarak() async {
    final jemput = _posisiJemput;
    final tujuan = _posisiTujuan;
    if (jemput == null || tujuan == null) return;

    setState(() => _sedangHitungRute = true);
    try {
      final km = await JarakRuteOsrm.kilometer(jemput, tujuan);
      if (!mounted) return;
      if (km != null && km > 0) {
        _jarakController.text = tulisJarak(double.parse(km.toStringAsFixed(1)));
      } else {
        final meter = const Distance().as(LengthUnit.Meter, jemput, tujuan);
        final perkiraanKm = (meter / 1000.0) * 1.25;
        final finalKm = (perkiraanKm < 0.3) ? 0.5 : perkiraanKm;
        _jarakController.text =
            tulisJarak(double.parse(finalKm.toStringAsFixed(1)));
      }
    } catch (_) {
      if (!mounted) return;
      final meter = const Distance().as(LengthUnit.Meter, jemput, tujuan);
      final perkiraanKm = (meter / 1000.0) * 1.25;
      final finalKm = (perkiraanKm < 0.3) ? 0.5 : perkiraanKm;
      _jarakController.text =
          tulisJarak(double.parse(finalKm.toStringAsFixed(1)));
    } finally {
      if (mounted) {
        setState(() => _sedangHitungRute = false);
      }
    }
  }

  HasilTarif? _hasilTarif(Tarif tarif) {
    final jarak = bacaJarak(_jarakController.text);
    if (jarak == null) return null;
    return KalkulatorTarif.anterJemput(jarakKm: jarak, tarif: tarif);
  }

  @override
  Widget build(BuildContext context) {
    final tarifAsync = ref.watch(tarifProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      body: tarifAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00AA13)),
        ),
        error: (galat, _) => SafeArea(
          child: PesanKosong(
            ikon: Icons.wifi_off_outlined,
            judul: 'Tarif gagal dimuat',
            keterangan: galat is GalatApi
                ? galat.pesan
                : 'Tidak bisa menghitung harga tanpa tarif. Coba lagi.',
            labelAksi: 'Coba lagi',
            onAksi: () => ref.invalidate(tarifProvider),
          ),
        ),
        data: (tarif) => _buildBody(context, tarif),
      ),
      bottomNavigationBar: tarifAsync.maybeWhen(
        data: (tarif) {
          final jarak = bacaJarak(_jarakController.text);
          final melebihiBatas =
              jarak != null && jarak > tarif.anjemJarakMaksimalKm;
          final hasil = melebihiBatas ? null : _hasilTarif(tarif);
          return _BilahBawahGojek(
            total: melebihiBatas ? null : hasil?.total,
            labelTotal: melebihiBatas ? 'Di Luar Batas' : null,
            labelAksi: melebihiBatas
                ? 'Maks. ${tarif.anjemJarakMaksimalKm.round()} km'
                : 'Pesan Sekarang',
            sedangMengirim: _sedangMengirim,
            onTekan: (hasil == null || melebihiBatas) ? null : _buatOrder,
            melebihiBatas: melebihiBatas,
          );
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildBody(BuildContext context, Tarif tarif) {
    final user = ref.watch(authRepositoryProvider).userAktif;
    final namaPanggilan = (user?.nama.isNotEmpty == true)
        ? user!.nama.trim().split(' ').first
        : 'Mahasiswa';

    final jarak = bacaJarak(_jarakController.text);
    final melebihiBatas =
        jarak != null && jarak > tarif.anjemJarakMaksimalKm;
    final hasil = melebihiBatas ? null : _hasilTarif(tarif);

    return SafeArea(
      top: false,
      child: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 1. Header Hijau Gojek Aloha (Ringkas & Bersih)
            _buildGojekHeader(context, namaPanggilan),

            const SizedBox(height: 14),

            // 2. Kartu Rute Terhubung dengan Autocomplete Dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildConnectedRouteCard(),
            ),

            const SizedBox(height: 14),

            // 3. Kartu Perkiraan Jarak (Akurat & Otomatis)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCardPerkiraanJarak(tarif),
            ),

            const SizedBox(height: 14),

            // 4. Kartu Catatan untuk Driver / Runner (Ringkas & Rapi)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCardCatatanDriver(),
            ),

            const SizedBox(height: 14),

            // 5. Kartu Rincian Tarif Kampus Terjangkau
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCardRincianTarif(
                hasil,
                melebihiBatas: melebihiBatas,
                tarif: tarif,
                jarak: jarak,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Header hijau Gojek Aloha yang ringkas tanpa banner berlebih
  Widget _buildGojekHeader(BuildContext context, String nama) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF00AA13),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 14,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Anter Jemput Kampus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Mau kemana hari ini, $nama?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dropdown saran lokasi kampus saat pengguna mengetik atau memilih kolom
  Widget _buildDropdownSaran({
    required List<LokasiKampusModel> daftar,
    required bool untukJemput,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E8D7), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PILIH LOKASI ${untukJemput ? "JEMPUT" : "TUJUAN"}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00AA13),
                    letterSpacing: 0.4,
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (untukJemput) {
                        _saranJemput = [];
                      } else {
                        _saranTujuan = [];
                      }
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF8A9A8C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE2EFE3), height: 1),
          for (final item in daftar)
            InkWell(
              onTap: () => _pilihSaran(item, untukJemput: untukJemput),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8EA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.ikon,
                        size: 16,
                        color: const Color(0xFF00AA13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nama,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E2124),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.sublabel != null)
                            Text(
                              item.sublabel!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7A6E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.north_west_rounded,
                      size: 14,
                      color: Color(0xFF00AA13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Kartu Rute Terhubung dengan input jemput & tujuan + live autocomplete
  Widget _buildConnectedRouteCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFEDF2ED), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titik Jemput
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFF00AA13), width: 2.5),
                ),
                child: Center(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00AA13),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LOKASI JEMPUT',
                      style: TextStyle(
                        color: Color(0xFF6B7A6E),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextFormField(
                      controller: _jemputController,
                      focusNode: _focusJemput,
                      maxLength: BatasMasukan.alamat,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        if (_posisiJemput == null && _saranJemput.isNotEmpty) {
                          _pilihSaran(_saranJemput.first, untukJemput: true);
                        }
                        _focusTujuan.requestFocus();
                      },
                      style: const TextStyle(
                        color: Color(0xFF1E2124),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                        hintText: 'Ketik nama gedung/kantin/pilih...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9EA8A0),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      onChanged: (val) =>
                          _saringSaran(val, untukJemput: true),
                      onTap: () => _saringSaran(
                        _jemputController.text,
                        untukJemput: true,
                      ),
                      validator: (nilai) => _wajibAlamat(nilai, 'jemput'),
                    ),
                  ],
                ),
              ),
              if (_sedangCariJemput)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00AA13),
                    ),
                  ),
                ),
              InkWell(
                onTap: () => _pilihDiPeta(
                  controller: _jemputController,
                  judul: 'Titik jemput',
                  untukJemput: true,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: Color(0xFF667368),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          // Tampilan Saran Dropdown Jemput
          if (_saranJemput.isNotEmpty)
            _buildDropdownSaran(daftar: _saranJemput, untukJemput: true),

          // Garis Penghubung Vertikal
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: SizedBox(
              height: 16,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  3,
                  (index) => Container(
                    width: 2,
                    height: 2.5,
                    color: const Color(0xFFBCC9BD),
                  ),
                ),
              ),
            ),
          ),

          // Titik Tujuan
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFFFF5722), width: 2.5),
                ),
                child: Center(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5722),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TUJUAN PENGANTARAN',
                      style: TextStyle(
                        color: Color(0xFFFF5722),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextFormField(
                      controller: _tujuanController,
                      focusNode: _focusTujuan,
                      maxLength: BatasMasukan.alamat,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (_posisiTujuan == null && _saranTujuan.isNotEmpty) {
                          _pilihSaran(_saranTujuan.first, untukJemput: false);
                        }
                      },
                      style: const TextStyle(
                        color: Color(0xFF1E2124),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                        hintText: 'Ketik tujuan/pilih dari daftar...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9EA8A0),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      onChanged: (val) =>
                          _saringSaran(val, untukJemput: false),
                      onTap: () => _saringSaran(
                        _tujuanController.text,
                        untukJemput: false,
                      ),
                      validator: (nilai) => _wajibAlamat(nilai, 'tujuan'),
                    ),
                  ],
                ),
              ),
              if (_sedangCariTujuan)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF5722),
                    ),
                  ),
                ),
              InkWell(
                onTap: () => _pilihDiPeta(
                  controller: _tujuanController,
                  judul: 'Titik tujuan',
                  untukJemput: false,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF667368),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          // Tampilan Saran Dropdown Tujuan
          if (_saranTujuan.isNotEmpty)
            _buildDropdownSaran(daftar: _saranTujuan, untukJemput: false),
        ],
      ),
    );
  }

  /// Kartu Perkiraan Jarak dengan indikator otomatis/menit dan peringatan jika melebihi batas
  Widget _buildCardPerkiraanJarak(Tarif tarif) {
    final jarak = bacaJarak(_jarakController.text);
    final bool melebihiBatas =
        jarak != null && jarak > tarif.anjemJarakMaksimalKm;
    final String menitEstimasi = jarak != null
        ? '(± ${(jarak * 2.5).clamp(4, 30).round()}-${(jarak * 3.5).clamp(8, 45).round()} menit)'
        : '(± 5-10 menit)';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: melebihiBatas
              ? const Color(0xFFFFB74D)
              : const Color(0xFFEDF2ED),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: melebihiBatas
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFE8F8EA),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  melebihiBatas
                      ? Icons.warning_amber_rounded
                      : Icons.access_time_filled_rounded,
                  color: melebihiBatas
                      ? const Color(0xFFE65100)
                      : const Color(0xFF00AA13),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PERKIRAAN JARAK & WAKTU',
                      style: TextStyle(
                        color: Color(0xFF6B7A6E),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        SizedBox(
                          width: 65,
                          child: TextFormField(
                            controller: _jarakController,
                            enabled: !_sedangHitungRute,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]')),
                            ],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: melebihiBatas
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFF1E2124),
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: '0.0',
                              suffixText: ' km',
                              suffixStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E2124),
                              ),
                            ),
                            validator: (nilai) => validasiJarak(nilai, tarif),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          menitEstimasi,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7A6E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_sedangHitungRute)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00AA13),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: melebihiBatas
                        ? const Color(0xFFFFF3E0)
                        : const Color(0xFFE8F8EA),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: melebihiBatas
                          ? const Color(0xFFE65100)
                          : const Color(0xFF00AA13),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    melebihiBatas ? 'Kejauhan' : 'Otomatis',
                    style: TextStyle(
                      color: melebihiBatas
                          ? const Color(0xFFE65100)
                          : const Color(0xFF00AA13),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (melebihiBatas) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFFE65100), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Jarak melebihi batas Anter Jemput (maks. ${tarif.anjemJarakMaksimalKm.round()} km)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB74700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Layanan Anter Jemput kampus hanya melayani perjalanan hingga ${tarif.anjemJarakMaksimalKm.round()} km. Karena jarak tujuan Anda ${tulisJarak(jarak)} km, silakan buat penawaran khusus lewat Jalur B (Permintaan Lain).',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5D4037),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      context.push(
                        Rute.formPermintaan(ServiceType.permintaanLain),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Pindah ke Permintaan Lain (Jalur B)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Kartu Catatan untuk Driver / Runner (Ringkas 1 baris bersih)
  Widget _buildCardCatatanDriver() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDF2ED), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Color(0xFFFF7043),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _catatanController,
              maxLength: BatasMasukan.deskripsi,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C352E),
              ),
              decoration: const InputDecoration(
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Catatan untuk driver (opsional)',
                hintStyle: TextStyle(
                  color: Color(0xFF9EA8A0),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Rincian Tarif Kampus Terjangkau
  Widget _buildCardRincianTarif(
    HasilTarif? hasil, {
    required bool melebihiBatas,
    required Tarif tarif,
    required double? jarak,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: melebihiBatas
              ? const Color(0xFFFFB74D)
              : const Color(0xFFEDF2ED),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF00AA13),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'RINCIAN TARIF',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E2124),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: melebihiBatas
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFE8F8EA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  melebihiBatas ? 'Di Luar Batas' : 'Tarif Mahasiswa',
                  style: TextStyle(
                    color: melebihiBatas
                        ? const Color(0xFFE65100)
                        : const Color(0xFF00880C),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (melebihiBatas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Jarak ${tulisJarak(jarak)} km melewati batas maksimal Anter Jemput (${tarif.anjemJarakMaksimalKm.round()} km). Tarif otomatis tidak berlaku untuk rute ini.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (hasil == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Pilih rute untuk melihat rincian tarif.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF8A968B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else ...[
            for (final baris in hasil.rincian)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      baris.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF4A554D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatRupiah(baris.nominal),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: baris.label.toLowerCase().contains('parkir') ||
                                baris.label.toLowerCase().contains('layanan')
                            ? const Color(0xFF00AA13)
                            : const Color(0xFF1E2124),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(color: Color(0xFFEDF2ED), height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Total Biaya',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2124),
                  ),
                ),
                Text(
                  formatRupiah(hasil.total),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF00AA13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _buatOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final jarak = bacaJarak(_jarakController.text);
    if (jarak == null) return;

    final tarifAsync = ref.read(tarifProvider);
    final tarif = tarifAsync.asData?.value;
    if (tarif != null && jarak > tarif.anjemJarakMaksimalKm) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Jarak ${tulisJarak(jarak)} km melebihi batas layanan (${tarif.anjemJarakMaksimalKm.round()} km). Gunakan Permintaan Lain.',
            ),
          ),
        );
      return;
    }

    setState(() => _sedangMengirim = true);

    final Order order;
    try {
      order = await ref
          .read(orderRepositoryProvider)
          .buatOrderJalurA(
            serviceType: ServiceType.anterJemput,
            jarakKm: jarak,
            deskripsi: _catatanController.text.trim().isEmpty
                ? null
                : _catatanController.text.trim(),
            alamatJemput: _jemputController.text.trim(),
            alamatTujuan: _tujuanController.text.trim(),
            idempotencyKey: _idempotencyKey,
          );
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMengirim = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi
                  ? galat.pesan
                  : 'Order gagal dibuat. Terjadi kendala sambungan atau server.',
            ),
          ),
        );
      return;
    }

    if (!mounted) return;
    setState(() => _sedangMengirim = false);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Order ${order.kodeOrder} dibuat')),
      );

    context.pushReplacement(Rute.detailOrder(order.id));
  }

  Future<void> _pilihDiPeta({
    required TextEditingController controller,
    required String judul,
    required bool untukJemput,
  }) async {
    final posisiSekarang = untukJemput ? _posisiJemput : _posisiTujuan;
    final hasil = await Navigator.of(context).push<HasilPilihLokasi>(
      MaterialPageRoute(
        builder: (context) =>
            PemilihLokasiScreen(judul: judul, posisiAwal: posisiSekarang),
      ),
    );
    if (hasil == null || !mounted) return;

    controller.text = hasil.alamat;
    setState(() {
      if (untukJemput) {
        _posisiJemput = hasil.posisi;
        _saranJemput = [];
      } else {
        _posisiTujuan = hasil.posisi;
        _saranTujuan = [];
      }
    });

    await _hitungOtomatisJarak();
  }

  static String? _wajibAlamat(String? nilai, String jenis) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Alamat $jenis wajib diisi';
    if (bersih.length < 3) return 'Tulis alamat $jenis lebih jelas';
    return null;
  }
}

/// Bilah bawah tombol aksi pemesanan ala Gojek yang bersih tanpa selector palsu
class _BilahBawahGojek extends StatelessWidget {
  const _BilahBawahGojek({
    required this.total,
    this.labelTotal,
    this.labelAksi = 'Pesan Sekarang',
    required this.sedangMengirim,
    required this.onTekan,
    this.melebihiBatas = false,
  });

  final int? total;
  final String? labelTotal;
  final String labelAksi;
  final bool sedangMengirim;
  final VoidCallback? onTekan;
  final bool melebihiBatas;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: sedangMengirim ? null : onTekan,
              style: FilledButton.styleFrom(
                backgroundColor: melebihiBatas
                    ? const Color(0xFFC4C4C4)
                    : const Color(0xFF00AA13),
                disabledBackgroundColor: melebihiBatas
                    ? const Color(0xFFE2E2E2)
                    : const Color(0xFFB0D9B3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: sedangMengirim
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              melebihiBatas ? 'Batas Layanan' : 'Total Tarif',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            Text(
                              total != null
                                  ? formatRupiah(total)
                                  : (labelTotal ?? 'Pilih Rute'),
                              style: TextStyle(
                                fontSize: melebihiBatas ? 13.5 : 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              labelAksi,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              melebihiBatas
                                  ? Icons.block_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
