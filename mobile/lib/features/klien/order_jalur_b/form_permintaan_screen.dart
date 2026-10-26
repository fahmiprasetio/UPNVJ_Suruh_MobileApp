import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/galat_api.dart';
import '../peta/pemilih_lokasi_screen.dart';
import '../../../core/api/idempotency_key.dart';
import '../../../core/config/batas_masukan.dart';

import '../../../core/format/formatters.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/service_catalog.dart';
import '../../../core/providers/repository_providers.dart';

/// Form Jalur B: klien menuliskan kebutuhannya, harga menyusul.
///
/// Satu layar ini melayani "Permintaan Lain", satu-satunya layanan Jalur B.
/// Yang membedakan Jalur B dari
/// Jalur A bukan isian formnya, melainkan tidak adanya harga di ujung
/// (rencana capstone bagian 3).
///
/// Karena itu layar ini sengaja tidak punya kalkulator, tidak punya total, dan
/// tidak punya tombol bayar. Menampilkan angka apa pun di sini akan
/// menjanjikan sesuatu yang belum tentu disanggupi runner.
class FormPermintaanScreen extends ConsumerStatefulWidget {
  const FormPermintaanScreen({
    super.key,
    required this.serviceType,
    this.contoh,
  });

  final ServiceType serviceType;

  /// Order lama yang isinya dipakai mengisi form ini di muka ("Pesan lagi"),
  /// dan null untuk form kosong seperti biasa.
  final Order? contoh;

  @override
  ConsumerState<FormPermintaanScreen> createState() =>
      _FormPermintaanScreenState();
}

class _FormPermintaanScreenState extends ConsumerState<FormPermintaanScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _idempotencyKey = buatIdempotencyKey();
  final _kebutuhanController = TextEditingController();
  final _alamatController = TextEditingController();
  final _hargaController = TextEditingController();

  int _jumlahRunner = 1;
  bool _sedangMengirim = false;
  Uint8List? _foto;
  String? _namaFoto;
  bool _sedangMemilihFoto = false;
  LatLng? _posisiAlamat;

  bool get _isKebersihan =>
      widget.serviceType == ServiceType.bersihKos ||
      widget.serviceType == ServiceType.bersihKamarMandi;

  /// Jadwal diisi di muka dengan besok pagi, bukan dibiarkan kosong.
  ///
  /// Jam sembilan besok adalah tebakan yang paling sering benar untuk
  /// pekerjaan terjadwal, dan isian yang sudah terisi lebih mudah dikoreksi
  /// daripada isian kosong yang harus diisi dari nol. Nilainya tetap tampil
  /// terang-terangan di layar, jadi tidak ada jadwal yang terkirim diam-diam.
  DateTime _jadwal = _besokPagi();

  static DateTime _besokPagi() {
    final besok = DateTime.now().add(const Duration(days: 1));
    return DateTime(besok.year, besok.month, besok.day, 9);
  }

  /// Alamat tersimpan mengisi sendiri kolom alamat.
  ///
  /// Pengisian ini sempat ditunda karena bentuk formulir Jalur B berbeda dari
  /// Jalur A: di sana ada sepasang kolom jemput dan tujuan, dan memilih yang
  /// salah menghasilkan order yang berangkat ke alamat keliru. Di sini
  /// kolomnya cuma satu, dan artinya sama untuk seluruh layanan Jalur B: tempat
  /// pekerjaannya dilakukan. Kos yang dibersihkan, kamar mandi yang disikat,
  /// dan kos asal yang barangnya dipindahkan sama-sama alamat orangnya sendiri;
  /// tujuan pindahan diceritakan di kolom kebutuhan, bukan di sini.
  ///
  /// Diisi, bukan ditawarkan lewat tombol "pakai alamat saya", mengikuti alasan
  /// yang sama seperti di Jalur A: isinya terlihat, bisa disunting, dan tetap
  /// divalidasi sebelum dikirim.
  ///
  /// Dibaca sekali di sini lewat `userAktif`, bukan ditonton lewat provider:
  /// alamat yang berubah di tengah orang mengetik formulir order tidak boleh
  /// menimpa apa yang sudah ia ketik.
  ///
  /// Order contoh menang atas alamat tersimpan, dengan alasan yang sama seperti
  /// di Jalur A. Yang sengaja TIDAK ikut disalin adalah jadwalnya: jadwal order
  /// lama sudah lewat, dan mengisinya di muka dengan tanggal kemarin berarti
  /// menawarkan satu-satunya nilai yang pasti salah. Besok pagi tetap tebakan
  /// yang lebih benar.
  ///
  /// Harga usulan ikut disalin apa adanya, walaupun harga akhir order lamanya
  /// mungkin berbeda sesudah tawar-menawar. Yang diminta form ini memang usulan
  /// pembuka, dan usulan yang dulu dipakai orangnya sendiri adalah titik awal
  /// yang lebih baik daripada kolom kosong.
  @override
  void initState() {
    super.initState();

    final contoh = widget.contoh;
    if (contoh != null) {
      _kebutuhanController.text = contoh.deskripsi ?? '';
      _alamatController.text = contoh.alamatTujuan ?? '';
      _hargaController.text = contoh.hargaUsulan?.toString() ?? '';
      _jumlahRunner = contoh.jumlahRunnerDibutuhkan;
      return;
    }

    final alamat = ref.read(authRepositoryProvider).userAktif?.alamat;
    if (alamat != null && alamat.isNotEmpty) {
      _alamatController.text = alamat;
    }
  }

  @override
  void dispose() {
    _kebutuhanController.dispose();
    _alamatController.dispose();
    _hargaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(widget.serviceType);
    final user = ref.watch(authRepositoryProvider).userAktif;
    final namaPanggilan = user?.nama.split(' ').first ?? 'Kak';
    final hargaParsed = int.tryParse(_hargaController.text.trim());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      body: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 1. Header Gojek Aloha
            _buildGojekHeader(context, layanan.nama, namaPanggilan),

            const SizedBox(height: 10),

            // 2. Info Sistem Penawaran
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildInfoPenawaranCard(),
            ),

            const SizedBox(height: 10),

            // 3. Kartu Alamat Pengerjaan (dengan Tombol Buka Peta)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAlamatCard(),
            ),

            const SizedBox(height: 10),

            // 4. Kartu Detail Kebutuhan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildKebutuhanCard(),
            ),

            const SizedBox(height: 10),

            // 5. Kartu Foto Kondisi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildFotoKondisiCard(),
            ),

            const SizedBox(height: 10),

            // 6. Kartu Jadwal & Jumlah Orang
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildJadwalDanRunnerCard(),
            ),

            const SizedBox(height: 10),

            // 7. Kartu Tawaran Harga Awal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTawaranHargaCard(),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _BilahBawahGojekPermintaan(
        total: hargaParsed,
        sedangMengirim: _sedangMengirim,
        onTekan: _sedangMengirim ? null : _kirimPermintaan,
      ),
    );
  }

  /// Header hijau Gojek Aloha yang ringkas & elegan
  Widget _buildGojekHeader(BuildContext context, String judul, String nama) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF00AA13)),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  judul,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Kirim kebutuhan & tawaran hargamu, $nama',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11.5,
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

  /// Kartu Informasi Alur Kerja Penawaran
  Widget _buildInfoPenawaranCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.forum_outlined, size: 18, color: Color(0xFF00AA13)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Layanan ini memakai sistem penawaran. Tulis kebutuhanmu dan buka tawaran awal, runner yang tersedia dapat langsung menyetujui atau menawar balik.',
              style: TextStyle(
                color: Color(0xFF1B5E20),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Detail Kebutuhan
  Widget _buildKebutuhanCard() {
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFF00AA13),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'DETAIL KEBUTUHAN',
                  style: TextStyle(
                    color: Color(0xFF00AA13),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _kebutuhanController,
            maxLength: BatasMasukan.deskripsi,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 4,
            minLines: 3,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E2124),
            ),
            decoration: const InputDecoration(
              counterText: '',
              labelText: 'Jelaskan bantuan yang kamu butuhkan...',
            ),
            validator: _validasiKebutuhan,
          ),
        ],
      ),
    );
  }

  /// Kartu Foto Kondisi untuk pertimbangan penawaran harga runner
  Widget _buildFotoKondisiCard() {
    final judulFoto = widget.serviceType == ServiceType.bersihKamarMandi
        ? 'FOTO KONDISI KAMAR MANDI'
        : widget.serviceType == ServiceType.bersihKos
        ? 'FOTO KONDISI KOS'
        : 'FOTO PENDUKUNG (OPSIONAL)';

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
        border: Border.all(
          color: _isKebersihan && _foto == null
              ? const Color(0xFFE2E8E2)
              : const Color(0xFFEDF2ED),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFF00AA13),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      judulFoto,
                      style: const TextStyle(
                        color: Color(0xFF00AA13),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Foto kondisi agar runner dapat memperkirakan beban kerja & harga',
                      style: TextStyle(
                        color: Color(0xFF6B7A6E),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_foto != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                _foto!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sedangMemilihFoto || _sedangMengirim
                      ? null
                      : _pilihFoto,
                  icon: Icon(
                    _foto == null
                        ? Icons.add_a_photo_outlined
                        : Icons.refresh_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _foto == null ? 'Pilih Foto Kondisi' : 'Ganti Foto',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00AA13),
                    side: const BorderSide(
                      color: Color(0xFF00AA13),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              if (_foto != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sedangMemilihFoto || _sedangMengirim
                      ? null
                      : () => setState(() {
                          _foto = null;
                          _namaFoto = null;
                        }),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  tooltip: 'Hapus Foto',
                ),
              ],
            ],
          ),
          if (_foto == null && _isKebersihan)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Wajib melampirkan foto kondisi untuk layanan ini.',
                style: TextStyle(
                  color: Color(0xFFD32F2F),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
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

  /// Kartu Tawaran Harga Awal
  Widget _buildTawaranHargaCard() {
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: Color(0xFF00AA13),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'TAWARAN HARGA AWAL',
                  style: TextStyle(
                    color: Color(0xFF00AA13),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _hargaController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E2124),
            ),
            decoration: const InputDecoration(
              labelText: 'Harga tawaran kamu',
              prefixText: 'Rp ',
            ),
            validator: _validasiHarga,
          ),
        ],
      ),
    );
  }

  /// Kartu Alamat Pengerjaan
  Widget _buildAlamatCard() {
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.place_outlined,
                  color: Color(0xFFFF7043),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'LOKASI PENGERJAAN',
                  style: TextStyle(
                    color: Color(0xFFFF7043),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _alamatController,
                  maxLength: BatasMasukan.alamat,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E2124),
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    labelText: 'Alamat tempat pengerjaan',
                  ),
                  validator: _validasiAlamat,
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _sedangMengirim ? null : _bukaPetaAlamat,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: Color(0xFFFF7043),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _bukaPetaAlamat() async {
    final hasil = await Navigator.of(context).push<HasilPilihLokasi>(
      MaterialPageRoute(
        builder: (_) => PemilihLokasiScreen(
          judul: 'Lokasi Pengerjaan',
          posisiAwal: _posisiAlamat,
        ),
      ),
    );
    if (hasil == null || !mounted) return;
    setState(() {
      _alamatController.text = hasil.alamat;
      _posisiAlamat = hasil.posisi;
    });
  }

  /// Kartu Jadwal & Jumlah Runner
  Widget _buildJadwalDanRunnerCard() {
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.event_outlined,
                  color: Color(0xFF00AA13),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JADWAL & RUNNER',
                      style: TextStyle(
                        color: Color(0xFF00AA13),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Kapan dikerjakan dan butuh berapa orang',
                      style: TextStyle(
                        color: Color(0xFF6B7A6E),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PemilihJadwal(
            nilai: _jadwal,
            onUbah: _sedangMengirim ? null : _pilihJadwal,
          ),
          const SizedBox(height: 16),
          const Text(
            'Jumlah Runner',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E2124),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 1 ? 0 : 4,
                      right: i == 3 ? 0 : 4,
                    ),
                    child: InkWell(
                      onTap: _sedangMengirim
                          ? null
                          : () => setState(() => _jumlahRunner = i),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _jumlahRunner == i
                              ? const Color(0xFF00AA13)
                              : const Color(0xFFF7F9F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _jumlahRunner == i
                                ? const Color(0xFF00AA13)
                                : const Color(0xFFE2E8E2),
                            width: _jumlahRunner == i ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$i Orang',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _jumlahRunner == i
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: _jumlahRunner == i
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
        ],
      ),
    );
  }

  Future<void> _kirimPermintaan() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isKebersihan && _foto == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Pilih foto kondisi terlebih dahulu agar runner dapat melihatnya.',
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
          .buatPermintaanJalurB(
            serviceType: widget.serviceType,
            deskripsi: _kebutuhanController.text.trim(),
            jadwalMulai: _jadwal,
            alamatTujuan: _alamatController.text.trim(),
            jumlahRunnerDibutuhkan: _jumlahRunner,
            hargaUsulan: int.parse(_hargaController.text.trim()),
            idempotencyKey: _idempotencyKey,
          );

      if (_foto != null && _namaFoto != null) {
        await ref
            .read(fotoBuktiRepositoryProvider)
            .unggahFotoEstimasi(
              orderId: order.id,
              namaBerkas: _namaFoto!,
              isi: _foto!,
            );
      }
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
                  : 'Permintaan atau foto gagal dikirim. Terjadi kendala sambungan atau server.',
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
        SnackBar(
          content: Text(
            'Permintaan ${order.kodeOrder} terkirim. Menunggu tawaran runner.',
          ),
        ),
      );

    context.pushReplacement(Rute.detailOrder(order.id));
  }

  Future<void> _pilihJadwal() async {
    final sekarang = DateTime.now();
    final tanggal = await showDatePicker(
      context: context,
      initialDate: _jadwal,
      // Permintaan untuk waktu yang sudah lewat tidak masuk akal, dan lebih
      // baik dicegah di pemilihnya daripada ditolak setelah dikirim.
      firstDate: DateTime(sekarang.year, sekarang.month, sekarang.day),
      lastDate: sekarang.add(const Duration(days: 90)),
    );
    if (tanggal == null || !mounted) return;

    final jam = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_jadwal),
    );
    if (jam == null || !mounted) return;

    setState(() {
      _jadwal = DateTime(
        tanggal.year,
        tanggal.month,
        tanggal.day,
        jam.hour,
        jam.minute,
      );
    });
  }

  static String? _validasiKebutuhan(String? nilai) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Ceritakan dulu apa yang kamu butuhkan';
    if (bersih.length < 20) {
      return 'Ceritakan lebih lengkap, runner tidak bisa memberi harga dari '
          'satu kalimat pendek';
    }
    return null;
  }

  static String? _validasiHarga(String? nilai) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Masukkan tawaran harga kamu';
    final angka = int.tryParse(bersih);
    if (angka == null || angka <= 0) return 'Masukkan angka yang masuk akal';
    return null;
  }

  static String? _validasiAlamat(String? nilai) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Alamat wajib diisi';
    if (bersih.length < 5) return 'Tulis alamat lebih jelas';
    return null;
  }
}

/// Pemilih tanggal dan jam pekerjaan.
///
/// Sebelum ada isian ini, klien diminta menyebut waktunya di dalam ceritanya,
/// dan runner harus menebaknya dari kalimat bebas. Jadwal yang terstruktur bisa
/// dibandingkan dengan jadwal penawaran, diurutkan, dan nanti dipakai
/// mengingatkan runner.
class _PemilihJadwal extends StatelessWidget {
  const _PemilihJadwal({required this.nilai, required this.onUbah});

  final DateTime nilai;
  final VoidCallback? onUbah;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      onPressed: onUbah,
      icon: const Icon(Icons.event_outlined),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(formatJadwal(nilai)),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        alignment: Alignment.centerLeft,
        foregroundColor: skema.onSurface,
        side: BorderSide(color: skema.outline),
      ),
    );
  }
}

class _BilahBawahGojekPermintaan extends StatelessWidget {
  const _BilahBawahGojekPermintaan({
    required this.total,
    required this.sedangMengirim,
    required this.onTekan,
  });

  final int? total;
  final bool sedangMengirim;
  final VoidCallback? onTekan;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
                backgroundColor: const Color(0xFF00AA13),
                disabledBackgroundColor: const Color(0xFFB0D9B3),
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
                              'Tawaran Awal',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            Text(
                              total != null && total! > 0
                                  ? formatRupiah(total)
                                  : 'Tawaran Bebas',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Text(
                              'Kirim Permintaan',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
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
