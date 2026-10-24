import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/api/idempotency_key.dart';
import '../../../core/config/batas_masukan.dart';
import '../../../core/format/formatters.dart';
import '../../../core/format/jarak.dart';
import '../../../core/peta/jarak_rute.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/pesan_kosong.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/models/tarif.dart';
import '../../../domain/pricing/kalkulator_tarif.dart';
import '../../../domain/service_catalog.dart';
import '../peta/pemilih_lokasi_screen.dart';
import 'widgets/ringkasan_harga.dart';

class FormLayananKosScreen extends ConsumerStatefulWidget {
  const FormLayananKosScreen({
    super.key,
    required this.serviceType,
    this.contoh,
  }) : assert(
         serviceType == ServiceType.bantuPindahKos ||
             serviceType == ServiceType.bersihKos ||
             serviceType == ServiceType.bersihKamarMandi,
       );

  final ServiceType serviceType;
  final Order? contoh;

  @override
  ConsumerState<FormLayananKosScreen> createState() =>
      _FormLayananKosScreenState();
}

class _FormLayananKosScreenState extends ConsumerState<FormLayananKosScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _idempotencyKey = buatIdempotencyKey();
  final _catatanController = TextEditingController();
  final _asalController = TextEditingController();
  final _tujuanController = TextEditingController();
  final _jarakController = TextEditingController();
  final _alamatController = TextEditingController();

  LatLng? _posisiAsal;
  LatLng? _posisiTujuan;
  int _jumlahRunner = 1;
  MovingVehicleType _jenisKendaraan = MovingVehicleType.pickup;
  Uint8List? _foto;
  String? _namaFoto;
  bool _sedangHitungRute = false;
  bool _sedangMemilihFoto = false;
  bool _sedangMengirim = false;

  bool get _pindahan => widget.serviceType == ServiceType.bantuPindahKos;
  bool get _kebersihan => !_pindahan;

  @override
  void initState() {
    super.initState();
    final contoh = widget.contoh;
    if (contoh != null) {
      _catatanController.text = contoh.deskripsi ?? '';
      _asalController.text = contoh.alamatJemput ?? '';
      _tujuanController.text = contoh.alamatTujuan ?? '';
      _alamatController.text = contoh.alamatTujuan ?? '';
      _jarakController.text = tulisJarak(contoh.jarakKm);
      _jumlahRunner = contoh.jumlahRunnerDibutuhkan;
      _jenisKendaraan = contoh.jenisKendaraan ?? MovingVehicleType.pickup;
      if (contoh.latitudeJemput != null && contoh.longitudeJemput != null) {
        _posisiAsal = LatLng(contoh.latitudeJemput!, contoh.longitudeJemput!);
      }
      if (contoh.latitudeTujuan != null && contoh.longitudeTujuan != null) {
        _posisiTujuan = LatLng(contoh.latitudeTujuan!, contoh.longitudeTujuan!);
      }
    } else {
      final alamat = ref.read(authRepositoryProvider).userAktif?.alamat;
      if (alamat != null && alamat.isNotEmpty) {
        if (_pindahan) {
          _asalController.text = alamat;
        } else {
          _alamatController.text = alamat;
        }
      }
    }
  }

  @override
  void dispose() {
    _catatanController.dispose();
    _asalController.dispose();
    _tujuanController.dispose();
    _jarakController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  HasilTarif? _hasilTarif(Tarif tarif) {
    if (_pindahan) {
      final jarak = bacaJarak(_jarakController.text);
      if (jarak == null) return null;
      return KalkulatorTarif.pindahKos(
        jarakKm: jarak,
        jumlahRunner: _jumlahRunner,
        jenisKendaraan: _jenisKendaraan,
        tarif: tarif,
      );
    }
    return KalkulatorTarif.hitung(widget.serviceType, null, tarif);
  }

  @override
  Widget build(BuildContext context) {
    final tarifAsync = ref.watch(tarifProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
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
        data: (tarif) => _isi(tarif),
      ),
      bottomNavigationBar: tarifAsync.maybeWhen(
        data: (tarif) {
          final hasil = _hasilTarif(tarif);
          final jarak = bacaJarak(_jarakController.text);
          final melebihiBatas =
              _pindahan && jarak != null && jarak > tarif.anjemJarakMaksimalKm;
          final bool bolehKirim =
              !_sedangMengirim &&
              (!_pindahan || (hasil != null && !melebihiBatas));

          return _BilahBawahGojekKos(
            total: hasil?.total,
            labelTotal: melebihiBatas
                ? 'Di Luar Batas'
                : (_pindahan ? 'Pilih Rute' : null),
            labelAksi: melebihiBatas
                ? 'Maks. ${tarif.anjemJarakMaksimalKm.round()} km'
                : 'Buat Order',
            sedangMengirim: _sedangMengirim,
            onTekan: bolehKirim ? _buatOrder : null,
            melebihiBatas: melebihiBatas,
          );
        },
        orElse: () => null,
      ),
    );
  }

  /// Header hijau Gojek Aloha yang ringkas & elegan
  Widget _buildGojekHeader(BuildContext context, String judul, String nama) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF00AA13)),
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
                Text(
                  judul,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _pindahan
                      ? 'Bantu angkut & pindahan praktis, $nama'
                      : 'Layanan kebersihan kos & kamar, $nama',
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

  Widget _isi(Tarif tarif) {
    final hasil = _hasilTarif(tarif);
    final user = ref.watch(authRepositoryProvider).userAktif;
    final namaPanggilan = user?.nama.split(' ').first ?? 'Kak';
    final jarak = bacaJarak(_jarakController.text);
    final melebihiBatas =
        _pindahan && jarak != null && jarak > tarif.anjemJarakMaksimalKm;

    return Form(
      key: _formKey,
      onChanged: () => setState(() {}),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. Header Gojek Aloha
          _buildGojekHeader(
            context,
            serviceInfoOf(widget.serviceType).nama,
            namaPanggilan,
          ),

          const SizedBox(height: 14),

          // 2. Konten Form Sesuai Jenis Layanan
          if (_pindahan) ...[
            // Kartu Rute Terhubung Pindahan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildConnectedRouteCardPindahan(tarif, melebihiBatas),
            ),
            const SizedBox(height: 14),
            // Kartu Opsi Runner & Kendaraan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildOpsiPindahanCard(),
            ),
            const SizedBox(height: 14),
            // Kartu Catatan Tambahan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCatatanCard('CATATAN TAMBAHAN (OPSIONAL)'),
            ),
          ] else ...[
            // Kartu Alamat Kos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildLokasiKosCard(),
            ),
            const SizedBox(height: 14),
            // Kartu Catatan Kondisi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCatatanCard('CATATAN KONDISI (OPSIONAL)'),
            ),
            const SizedBox(height: 14),
            // Kartu Foto Kondisi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildFotoKondisiCard(),
            ),
          ],

          const SizedBox(height: 14),

          // 3. Ringkasan Tarif / Peringatan Batas Jarak
          if (melebihiBatas)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD32F2F),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Jarak melebihi batas layanan (${tarif.anjemJarakMaksimalKm.round()} km). Gunakan Jalur B untuk jarak jauh.',
                        style: const TextStyle(
                          color: Color(0xFFC62828),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (hasil != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RingkasanHarga(hasil: hasil),
            ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  /// Kartu Rute Terhubung Pindahan Kos (Asal & Tujuan)
  Widget _buildConnectedRouteCardPindahan(Tarif tarif, bool melebihiBatas) {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titik Asal
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00AA13),
                    width: 2.5,
                  ),
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
                      'LOKASI ASAL PINDAHAN',
                      style: TextStyle(
                        color: Color(0xFF00AA13),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextFormField(
                      controller: _asalController,
                      maxLength: BatasMasukan.alamat,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        color: Color(0xFF1E2124),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                        hintText: 'Lokasi asal kos/kontrakan',
                        hintStyle: TextStyle(
                          color: Color(0xFF9EA8A0),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      validator: _validasiAlamat,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              InkWell(
                onTap: () =>
                    _pilihLokasi(_asalController, 'Lokasi asal pindahan', true),
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
                    color: Color(0xFF00AA13),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          // Garis Penghubung Vertikal
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: SizedBox(
              height: 18,
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
                  border: Border.all(
                    color: const Color(0xFFFF5722),
                    width: 2.5,
                  ),
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
                      'LOKASI TUJUAN PINDAHAN',
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
                      maxLength: BatasMasukan.alamat,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        color: Color(0xFF1E2124),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                        hintText: 'Lokasi tujuan pindahan',
                        hintStyle: TextStyle(
                          color: Color(0xFF9EA8A0),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      validator: _validasiAlamat,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              InkWell(
                onTap: () => _pilihLokasi(
                  _tujuanController,
                  'Lokasi tujuan pindahan',
                  false,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: Color(0xFFFF5722),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          // Jarak & Status Rute
          if (_sedangHitungRute) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00AA13),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Menghitung rute...',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7A6E)),
                ),
              ],
            ),
          ] else if (_jarakController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: melebihiBatas
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 15,
                    color: melebihiBatas
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF00AA13),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Jarak: ${_jarakController.text} km',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: melebihiBatas
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF00AA13),
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

  /// Kartu Opsi Pindahan (Jumlah Runner & Kendaraan)
  Widget _buildOpsiPindahanCard() {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_alt_outlined,
                  color: Color(0xFF00AA13),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JUMLAH RUNNER',
                      style: TextStyle(
                        color: Color(0xFF00AA13),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pilih berapa orang yang dibutuhkan',
                      style: TextStyle(
                        color: Color(0xFF6B7A6E),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_jumlahRunner Orang',
                  style: const TextStyle(
                    color: Color(0xFF00AA13),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var nilai = 1; nilai <= 5; nilai++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: nilai == 1 ? 0 : 4,
                      right: nilai == 5 ? 0 : 4,
                    ),
                    child: InkWell(
                      onTap: _sedangMengirim
                          ? null
                          : () => setState(() => _jumlahRunner = nilai),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _jumlahRunner == nilai
                              ? const Color(0xFF00AA13)
                              : const Color(0xFFF7F9F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _jumlahRunner == nilai
                                ? const Color(0xFF00AA13)
                                : const Color(0xFFE2E8E2),
                            width: _jumlahRunner == nilai ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$nilai',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: _jumlahRunner == nilai
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: _jumlahRunner == nilai
                                  ? Colors.white
                                  : const Color(0xFF2C352E),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFEDF2ED), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF00AA13),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KENDARAAN RUNNER',
                      style: TextStyle(
                        color: Color(0xFF00AA13),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Runner menyediakan armada pilihanmu',
                      style: TextStyle(
                        color: Color(0xFF6B7A6E),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MovingVehicleType>(
            initialValue: _jenisKendaraan,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            items: [
              for (final kendaraan in MovingVehicleType.values)
                DropdownMenuItem(
                  value: kendaraan,
                  child: Text(kendaraan.label),
                ),
            ],
            onChanged: _sedangMengirim
                ? null
                : (nilai) {
                    if (nilai != null) setState(() => _jenisKendaraan = nilai);
                  },
          ),
        ],
      ),
    );
  }

  /// Kartu Lokasi Kos (Bersih-Bersih)
  Widget _buildLokasiKosCard() {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00AA13),
                    width: 2.5,
                  ),
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
              const Text(
                'LOKASI KOS',
                style: TextStyle(
                  color: Color(0xFF00AA13),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _alamatController,
                  maxLength: BatasMasukan.alamat,
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E2124),
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: 'Alamat kos lengkap (kamar, nomor, patokan)',
                  ),
                  validator: _validasiAlamat,
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _sedangMengirim
                    ? null
                    : () => _pilihLokasi(
                        _alamatController,
                        'Lokasi kos/kontrakan',
                        true,
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
                    color: Color(0xFF00AA13),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Kartu Catatan Tambahan / Kondisi
  Widget _buildCatatanCard(String judul) {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notes_rounded,
                  color: Color(0xFFFF9800),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      judul,
                      style: const TextStyle(
                        color: Color(0xFFFF9800),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tulis detail yang perlu diperhatikan runner',
                      style: TextStyle(
                        color: Color(0xFF6B7A6E),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _catatanController,
            maxLength: BatasMasukan.deskripsi,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E2124),
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'Contoh: Lantai 2, banyak barang/perlu sikat...',
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Foto Kondisi (Wajib untuk Bersih Kos / Kamar Mandi)
  Widget _buildFotoKondisiCard() {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFF00AA13),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FOTO KONDISI KOS',
                      style: TextStyle(
                        color: Color(0xFF00AA13),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Foto wajib agar runner dapat memperkirakan kerjaan',
                      style: TextStyle(
                        color: Color(0xFF6B7A6E),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_foto != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _foto!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: _sedangMemilihFoto || _sedangMengirim
                ? null
                : _pilihFoto,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(_foto == null ? 'Pilih Foto Kondisi' : 'Ganti Foto'),
          ),
          if (_foto == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Foto kondisi belum dipilih.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String? _validasiAlamat(String? nilai) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Alamat wajib diisi';
    if (bersih.length < 5) return 'Tulis alamat lebih jelas';
    return null;
  }

  Future<void> _pilihLokasi(
    TextEditingController controller,
    String judul,
    bool untukAsal,
  ) async {
    final hasil = await Navigator.of(context).push<HasilPilihLokasi>(
      MaterialPageRoute(
        builder: (_) => PemilihLokasiScreen(
          judul: judul,
          posisiAwal: untukAsal ? _posisiAsal : _posisiTujuan,
        ),
      ),
    );
    if (hasil == null || !mounted) return;
    controller.text = hasil.alamat;
    setState(() {
      if (untukAsal) {
        _posisiAsal = hasil.posisi;
      } else {
        _posisiTujuan = hasil.posisi;
      }
    });

    if (_posisiAsal == null || _posisiTujuan == null) return;
    setState(() => _sedangHitungRute = true);
    double? jarakFinal;
    try {
      final kilometer = await JarakRuteOsrm.kilometer(
        _posisiAsal!,
        _posisiTujuan!,
      );
      if (kilometer != null && kilometer > 0) {
        jarakFinal = double.parse(kilometer.toStringAsFixed(1));
      }
    } catch (_) {}

    if (jarakFinal == null) {
      final meter = const Distance().as(
        LengthUnit.Meter,
        _posisiAsal!,
        _posisiTujuan!,
      );
      final perkiraanKm = (meter / 1000.0) * 1.25;
      jarakFinal = double.parse(
        ((perkiraanKm < 0.3) ? 0.5 : perkiraanKm).toStringAsFixed(1),
      );
    }

    if (!mounted) return;
    setState(() {
      _sedangHitungRute = false;
      _jarakController.text = tulisJarak(jarakFinal!);
    });
  }

  Future<void> _pilihFoto() async {
    setState(() => _sedangMemilihFoto = true);
    try {
      final pilihan = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (pilihan == null || !mounted) return;
      final isi = await pilihan.readAsBytes();
      if (!mounted) return;
      setState(() {
        _foto = isi;
        _namaFoto = pilihan.name;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto gagal dibuka. Coba foto lain.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sedangMemilihFoto = false);
    }
  }

  Future<void> _buatOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kebersihan && _foto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih foto kondisi terlebih dahulu.')),
      );
      return;
    }

    final jarak = _pindahan ? bacaJarak(_jarakController.text) : null;
    if (_pindahan && jarak == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih lokasi asal dan tujuan pindahan pada peta.'),
        ),
      );
      return;
    }

    setState(() => _sedangMengirim = true);
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .buatOrderJalurA(
            serviceType: widget.serviceType,
            jarakKm: jarak,
            deskripsi: _catatanController.text.trim().isEmpty
                ? null
                : _catatanController.text.trim(),
            alamatJemput: _pindahan ? _asalController.text.trim() : null,
            alamatTujuan: _pindahan
                ? _tujuanController.text.trim()
                : _alamatController.text.trim(),
            latitudeJemput: _posisiAsal?.latitude,
            longitudeJemput: _posisiAsal?.longitude,
            latitudeTujuan: _posisiTujuan?.latitude,
            longitudeTujuan: _posisiTujuan?.longitude,
            jumlahRunnerDibutuhkan: _pindahan ? _jumlahRunner : 1,
            jenisKendaraan: _pindahan ? _jenisKendaraan : null,
            idempotencyKey: _idempotencyKey,
          );

      if (_kebersihan) {
        await ref
            .read(fotoBuktiRepositoryProvider)
            .unggahFotoEstimasi(
              orderId: order.id,
              namaBerkas: _namaFoto!,
              isi: _foto!,
            );
      }

      if (!mounted) return;
      context.pushReplacement(Rute.detailOrder(order.id));
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMengirim = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            galat is GalatApi
                ? galat.pesan
                : 'Order atau foto gagal dikirim. Periksa sambungan lalu coba lagi.',
          ),
        ),
      );
    }
  }
}

/// Bilah bawah tombol aksi pemesanan layanan kos ala Gojek
class _BilahBawahGojekKos extends StatelessWidget {
  const _BilahBawahGojekKos({
    required this.total,
    this.labelTotal,
    this.labelAksi = 'Buat Order',
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
                              melebihiBatas ? 'Batas Layanan' : 'Total Biaya',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            Text(
                              total != null
                                  ? formatRupiah(total)
                                  : (labelTotal ?? '-'),
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
