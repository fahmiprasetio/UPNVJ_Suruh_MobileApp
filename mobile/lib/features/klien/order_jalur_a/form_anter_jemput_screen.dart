import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/api/idempotency_key.dart';
import '../../../core/config/batas_masukan.dart';
import '../../../core/router/app_router.dart';
import '../../../core/format/formatters.dart';
import '../../../core/format/jarak.dart';
import '../../../core/peta/geocoding_osm.dart';
import '../../../core/peta/jarak_rute.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/models/tarif.dart';
import '../../../domain/pricing/kalkulator_tarif.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/widgets/pesan_kosong.dart';
import '../peta/pemilih_lokasi_screen.dart';
import 'widgets/ringkasan_harga.dart';

// ---------------------------------------------------------------------------
// Model saran lokasi lokal (kampus, transit populer)
// ---------------------------------------------------------------------------

/// Titik lokasi kampus/transit yang dikenal tanpa perlu hit Nominatim.
class _LokasiLokal {
  const _LokasiLokal({
    required this.nama,
    required this.posisi,
    this.sublabel,
  });

  final String nama;
  final LatLng posisi;
  final String? sublabel;
}

/// Daftar titik kampus UPNVJ Pondok Labu, Limo, dan transit populer.
const List<_LokasiLokal> _daftarLokasiLokal = [
  _LokasiLokal(
    nama: 'Gedung Kuliah Bersama (GKB) UPNVJ',
    posisi: LatLng(-6.2895, 106.7853),
    sublabel: 'Gedung perkuliahan utama',
  ),
  _LokasiLokal(
    nama: 'Perpustakaan Pusat UPNVJ',
    posisi: LatLng(-6.2890, 106.7850),
    sublabel: 'Gedung Perpustakaan & Laboratorium',
  ),
  _LokasiLokal(
    nama: 'Kantin Vokasi, Gedung C UPNVJ',
    posisi: LatLng(-6.2901, 106.7858),
    sublabel: 'Area pujasera & nongkrong mahasiswa',
  ),
  _LokasiLokal(
    nama: 'Gedung FIK Kampus Pondok Labu',
    posisi: LatLng(-6.2898, 106.7862),
    sublabel: 'Fakultas Ilmu Komputer',
  ),
  _LokasiLokal(
    nama: 'Gedung Rektorat UPNVJ',
    posisi: LatLng(-6.2892, 106.7848),
    sublabel: 'Gedung Rektorat & Tata Usaha',
  ),
  _LokasiLokal(
    nama: 'Plaza Wardhana UPNVJ',
    posisi: LatLng(-6.2894, 106.7851),
    sublabel: 'Pusat kegiatan terbuka mahasiswa',
  ),
  _LokasiLokal(
    nama: 'Gedung FEB UPNVJ',
    posisi: LatLng(-6.2896, 106.7855),
    sublabel: 'Fakultas Ekonomi dan Bisnis',
  ),
  _LokasiLokal(
    nama: 'Gedung FISIP UPNVJ',
    posisi: LatLng(-6.2899, 106.7849),
    sublabel: 'Fakultas Ilmu Sosial dan Ilmu Politik',
  ),
  _LokasiLokal(
    nama: 'Gedung Fakultas Hukum UPNVJ',
    posisi: LatLng(-6.2903, 106.7852),
    sublabel: 'Gedung FH UPNVJ',
  ),
  _LokasiLokal(
    nama: 'Kampus UPNVJ Limo - Gedung Wahidin',
    posisi: LatLng(-6.3475, 106.7868),
    sublabel: 'Fakultas Kedokteran & Teknik Limo',
  ),
  _LokasiLokal(
    nama: 'Kantin Kampus Limo UPNVJ',
    posisi: LatLng(-6.3479, 106.7872),
    sublabel: 'Area kantin mahasiswa Limo',
  ),
  _LokasiLokal(
    nama: 'Halte Busway Kampus UPNVJ Pondok Labu',
    posisi: LatLng(-6.2885, 106.7865),
    sublabel: 'Pintu gerbang depan Jl. RS Fatmawati',
  ),
  _LokasiLokal(
    nama: 'Stasiun MRT Fatmawati Indomaret',
    posisi: LatLng(-6.2926, 106.7938),
    sublabel: 'Stasiun MRT terdekat',
  ),
  _LokasiLokal(
    nama: 'Stasiun KRL Lenteng Agung',
    posisi: LatLng(-6.3315, 106.8347),
    sublabel: 'Stasiun Commuter Line transit',
  ),
  _LokasiLokal(
    nama: 'Indomaret Pondok Labu Raya',
    posisi: LatLng(-6.2905, 106.7860),
    sublabel: 'Minimarket & titik temu favorit',
  ),
];

// ---------------------------------------------------------------------------
// Model saran gabungan (lokal + Nominatim)
// ---------------------------------------------------------------------------

/// Satu baris saran di dropdown autocomplete, bisa dari lokal atau Nominatim.
class _SaranLokasi {
  const _SaranLokasi({
    required this.nama,
    required this.posisi,
    this.sublabel,
    this.dariOsm = false,
  });

  final String nama;
  final LatLng posisi;
  final String? sublabel;

  /// `true` kalau hasil dari Nominatim, supaya UI bisa membedakan ikon.
  final bool dariOsm;
}

// ---------------------------------------------------------------------------
// Form Jalur A untuk Anter Jemput
// ---------------------------------------------------------------------------

/// Form Jalur A untuk Anter Jemput.
///
/// Ciri Jalur A: harga sudah pasti sebelum order dibuat, jadi klien melihat
/// totalnya berubah langsung sambil mengisi, tidak ada fase menunggu
/// penawaran (rencana capstone bagian 3).
///
/// Autocomplete: kolom jemput & tujuan mencari lokasi dari daftar kampus lokal
/// terlebih dahulu, lalu fallback ke Nominatim (OpenStreetMap) untuk alamat
/// umum. Debounce 500 ms supaya Nominatim tidak dibombardir tiap keystroke.
class FormAnterJemputScreen extends ConsumerStatefulWidget {
  const FormAnterJemputScreen({super.key, this.contoh});

  /// Order lama yang isinya dipakai mengisi form ini di muka ("Pesan lagi"),
  /// dan null untuk form kosong seperti biasa.
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

  bool _sedangMengirim = false;
  bool _sedangHitungRute = false;
  bool _sedangCariJemput = false;
  bool _sedangCariTujuan = false;

  /// Titik dari peta atau autocomplete, untuk menghitung jarak OSRM otomatis.
  LatLng? _posisiJemput;
  LatLng? _posisiTujuan;

  /// Saran dropdown aktif untuk masing-masing kolom.
  List<_SaranLokasi> _saranJemput = [];
  List<_SaranLokasi> _saranTujuan = [];

  /// Timer debounce untuk pencarian Nominatim.
  Timer? _debounceJemput;
  Timer? _debounceTujuan;

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
  // Pencarian lokasi: lokal terlebih dahulu, Nominatim sebagai fallback
  // -------------------------------------------------------------------------

  /// Cari di daftar lokal kampus terlebih dahulu. Kalau ketemu ≥ 1 → tampilkan.
  /// Kalau kosong → debounce 500 ms lalu panggil `GeocodingOsm.cari()`.
  void _cariLokasi(String kueri, {required bool untukJemput}) {
    final q = kueri.trim().toLowerCase();

    // Batal debounce sebelumnya
    if (untukJemput) {
      _debounceJemput?.cancel();
    } else {
      _debounceTujuan?.cancel();
    }

    if (q.isEmpty) {
      // Kosong → tampilkan 4 rekomendasi lokal awal
      final rekomendasiAwal = _daftarLokasiLokal
          .take(4)
          .map((l) => _SaranLokasi(
                nama: l.nama,
                posisi: l.posisi,
                sublabel: l.sublabel,
              ))
          .toList();

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

    // Cek lokal dulu
    final hasilLokal = _daftarLokasiLokal.where((l) {
      return l.nama.toLowerCase().contains(q) ||
          (l.sublabel?.toLowerCase().contains(q) ?? false);
    }).take(4).map((l) => _SaranLokasi(
          nama: l.nama,
          posisi: l.posisi,
          sublabel: l.sublabel,
        )).toList();

    if (hasilLokal.isNotEmpty) {
      // Lokal cocok → langsung tampilkan tanpa hit jaringan
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

    // Tidak ada lokal → debounce lalu panggil Nominatim
    setState(() {
      if (untukJemput) {
        _sedangCariJemput = true;
        _saranJemput = [];
      } else {
        _sedangCariTujuan = true;
        _saranTujuan = [];
      }
    });

    final timer = Timer(const Duration(milliseconds: 500), () {
      _cariDariNominatim(kueri.trim(), untukJemput: untukJemput);
    });

    if (untukJemput) {
      _debounceJemput = timer;
    } else {
      _debounceTujuan = timer;
    }
  }

  Future<void> _cariDariNominatim(
    String kueri, {
    required bool untukJemput,
  }) async {
    final hasil = await GeocodingOsm.cari(kueri);
    if (!mounted) return;

    final saran = hasil
        .take(4)
        .map((h) => _SaranLokasi(
              nama: h.alamat,
              posisi: h.posisi,
              dariOsm: true,
            ))
        .toList();

    setState(() {
      if (untukJemput) {
        _saranJemput = saran;
        _sedangCariJemput = false;
      } else {
        _saranTujuan = saran;
        _sedangCariTujuan = false;
      }
    });
  }

  /// Pengguna memilih satu saran dari dropdown.
  void _pilihSaran(_SaranLokasi item, {required bool untukJemput}) {
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

  // -------------------------------------------------------------------------
  // Hitung jarak otomatis via OSRM ketika kedua titik sudah terisi
  // -------------------------------------------------------------------------

  Future<void> _hitungOtomatisJarak() async {
    final jemput = _posisiJemput;
    final tujuan = _posisiTujuan;
    if (jemput == null || tujuan == null) return;

    setState(() => _sedangHitungRute = true);
    try {
      final km = await JarakRuteOsrm.kilometer(jemput, tujuan);
      if (!mounted) return;
      if (km != null && km > 0) {
        _jarakController.text =
            tulisJarak(double.parse(km.toStringAsFixed(1)));
      } else {
        // Fallback perkiraan garis lurus × faktor kelokan jalan
        final meter =
            const Distance().as(LengthUnit.Meter, jemput, tujuan);
        final perkiraanKm = (meter / 1000.0) * 1.25;
        final finalKm = (perkiraanKm < 0.3) ? 0.5 : perkiraanKm;
        _jarakController.text =
            tulisJarak(double.parse(finalKm.toStringAsFixed(1)));
      }
    } catch (_) {
      if (!mounted) return;
      final meter =
          const Distance().as(LengthUnit.Meter, jemput, tujuan);
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

  // -------------------------------------------------------------------------
  // Tarif
  // -------------------------------------------------------------------------

  /// `null` selama jarak belum diisi dengan angka yang masuk akal, harga
  /// memang belum bisa dihitung, dan menampilkan Rp 0 akan menyesatkan.
  HasilTarif? _hasilTarif(Tarif tarif) {
    final jarak = bacaJarak(_jarakController.text);
    if (jarak == null) return null;
    return KalkulatorTarif.anterJemput(jarakKm: jarak, tarif: tarif);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tarifAsync = ref.watch(tarifProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Anter Jemput')),
      body: tarifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (galat, _) => PesanKosong(
          ikon: Icons.wifi_off_outlined,
          judul: 'Tarif gagal dimuat',
          keterangan: galat is GalatApi
              ? galat.pesan
              : 'Tidak bisa menghitung harga tanpa tarif. Coba lagi.',
          labelAksi: 'Coba lagi',
          onAksi: () => ref.invalidate(tarifProvider),
        ),
        data: (tarif) => _buildForm(context, tarif),
      ),
      bottomNavigationBar: tarifAsync.maybeWhen(
        data: (tarif) {
          final hasil = _hasilTarif(tarif);
          return _BilahBuatOrder(
            total: hasil?.total,
            sedangMengirim: _sedangMengirim,
            onTekan: hasil == null ? null : _buatOrder,
          );
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildForm(BuildContext context, Tarif tarif) {
    final hasil = _hasilTarif(tarif);
    final skema = Theme.of(context).colorScheme;

    return SafeArea(
      child: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spasiSedang),
          children: [
            // --- Kolom Jemput dengan autocomplete ---
            TextFormField(
              controller: _jemputController,
              focusNode: _focusJemput,
              maxLength: BatasMasukan.alamat,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                counterText: '',
                labelText: 'Dijemput di mana?',
                hintText: 'Ketik alamat, gedung, stasiun...',
                prefixIcon: const Icon(Icons.my_location_outlined),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_sedangCariJemput)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.map_outlined),
                      tooltip: 'Pilih di peta',
                      onPressed: () => _pilihDiPeta(
                        controller: _jemputController,
                        judul: 'Titik jemput',
                        untukJemput: true,
                      ),
                    ),
                  ],
                ),
              ),
              onChanged: (val) => _cariLokasi(val, untukJemput: true),
              onTap: () => _cariLokasi(
                _jemputController.text,
                untukJemput: true,
              ),
              validator: (nilai) => _wajibAlamat(nilai, 'jemput'),
            ),

            // Dropdown saran jemput
            if (_saranJemput.isNotEmpty)
              _buildDropdownSaran(
                daftar: _saranJemput,
                untukJemput: true,
              ),

            const SizedBox(height: AppTheme.spasiSedang),

            // --- Kolom Tujuan dengan autocomplete ---
            TextFormField(
              controller: _tujuanController,
              focusNode: _focusTujuan,
              maxLength: BatasMasukan.alamat,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                counterText: '',
                labelText: 'Diantar ke mana?',
                hintText: 'Ketik alamat, gedung, stasiun...',
                prefixIcon: const Icon(Icons.place_outlined),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_sedangCariTujuan)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.map_outlined),
                      tooltip: 'Pilih di peta',
                      onPressed: () => _pilihDiPeta(
                        controller: _tujuanController,
                        judul: 'Titik tujuan',
                        untukJemput: false,
                      ),
                    ),
                  ],
                ),
              ),
              onChanged: (val) => _cariLokasi(val, untukJemput: false),
              onTap: () => _cariLokasi(
                _tujuanController.text,
                untukJemput: false,
              ),
              validator: (nilai) => _wajibAlamat(nilai, 'tujuan'),
            ),

            // Dropdown saran tujuan
            if (_saranTujuan.isNotEmpty)
              _buildDropdownSaran(
                daftar: _saranTujuan,
                untukJemput: false,
              ),

            const SizedBox(height: AppTheme.spasiSedang),

            // --- Kolom jarak ---
            TextFormField(
              controller: _jarakController,
              enabled: !_sedangHitungRute,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                counterText: '',
                labelText: 'Perkiraan jarak',
                suffixText: 'km',
                prefixIcon: const Icon(Icons.straighten_outlined),
                helperText: _sedangHitungRute
                    ? 'Menghitung jarak rute jalan...'
                    : null,
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (nilai) => validasiJarak(nilai, tarif),
            ),
            const SizedBox(height: AppTheme.spasiKecil),
            Text(
              'Perkiraan saja, runner dan kamu bisa sesuaikan di lapangan '
              'kalau meleset jauh.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spasiSedang),

            // --- Catatan ---
            TextFormField(
              controller: _catatanController,
              maxLength: BatasMasukan.deskripsi,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                counterText: '',
                labelText: 'Catatan untuk runner (opsional)',
                hintText: 'Tunggu di gerbang depan, pakai jaket merah',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
            ),
            const SizedBox(height: AppTheme.spasiBesar),
            if (hasil == null)
              const _HargaBelumBisaDihitung()
            else
              RingkasanHarga(hasil: hasil),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Dropdown saran autocomplete
  // -------------------------------------------------------------------------

  Widget _buildDropdownSaran({
    required List<_SaranLokasi> daftar,
    required bool untukJemput,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < daftar.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            InkWell(
              onTap: () => _pilihSaran(daftar[i], untukJemput: untukJemput),
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? const Radius.circular(12) : Radius.zero,
                bottom: i == daftar.length - 1
                    ? const Radius.circular(12)
                    : Radius.zero,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      daftar[i].dariOsm
                          ? Icons.public_rounded
                          : Icons.location_on_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            daftar[i].nama,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (daftar[i].sublabel != null)
                            Text(
                              daftar[i].sublabel!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.north_west_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Buat order
  // -------------------------------------------------------------------------

  Future<void> _buatOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final jarak = bacaJarak(_jarakController.text);
    if (jarak == null) return;

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

  // -------------------------------------------------------------------------
  // Pilih di peta
  // -------------------------------------------------------------------------

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
    if (bersih.length < 5) return 'Tulis alamat $jenis lebih jelas';
    return null;
  }
}

// ---------------------------------------------------------------------------
// Widget pembantu
// ---------------------------------------------------------------------------

class _HargaBelumBisaDihitung extends StatelessWidget {
  const _HargaBelumBisaDihitung();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Row(
          children: [
            Icon(Icons.calculate_outlined, color: skema.onSurfaceVariant),
            const SizedBox(width: AppTheme.spasiSedang),
            Expanded(
              child: Text(
                'Isi perkiraan jarak dulu, harganya langsung muncul di sini.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: skema.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BilahBuatOrder extends StatelessWidget {
  const _BilahBuatOrder({
    required this.total,
    required this.sedangMengirim,
    required this.onTekan,
  });

  final int? total;
  final bool sedangMengirim;
  final VoidCallback? onTekan;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (total != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bayar nanti',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: skema.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatRupiah(total),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: skema.primary,
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton(
              onPressed: sedangMengirim ? null : onTekan,
              child: sedangMengirim
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Buat Order'),
            ),
          ],
        ),
      ),
    );
  }
}
