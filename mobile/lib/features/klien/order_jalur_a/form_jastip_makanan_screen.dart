import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/api/idempotency_key.dart';
import '../../../core/config/batas_masukan.dart';
import '../../../core/format/formatters.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/pricing/kalkulator_tarif.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/widgets/pesan_kosong.dart';
import '../peta/pemilih_lokasi_screen.dart';

/// Form Jalur A untuk Jastip Makanan dengan Desain Modern Gojek Aloha.
///
/// Menyediakan pemilihan makanan/minuman dengan quick chips, pemilihan lokasi
/// warung & lokasi pengantaran dengan peta interaktif terhubung (connected route),
/// rincian ongkos jasa titip flat Rp 8.000, dan edukasi pembayaran harga fisik makanan.
class FormJastipMakananScreen extends ConsumerStatefulWidget {
  const FormJastipMakananScreen({super.key, this.contoh});

  /// Order lama yang isinya dipakai mengisi form ini di muka ("Pesan lagi"),
  /// dan null untuk form kosong seperti biasa.
  final Order? contoh;

  @override
  ConsumerState<FormJastipMakananScreen> createState() =>
      _FormJastipMakananScreenState();
}

class _FormJastipMakananScreenState
    extends ConsumerState<FormJastipMakananScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _idempotencyKey = buatIdempotencyKey();
  final _makananController = TextEditingController();
  final _belipController = TextEditingController();
  final _tujuanController = TextEditingController();

  final _focusMakanan = FocusNode();
  final _focusBeli = FocusNode();
  final _focusTujuan = FocusNode();

  bool _sedangMengirim = false;

  /// Titik peta untuk kolom warung, kalau diisi lewat sana.
  LatLng? _posisiBeli;

  /// Titik peta untuk kolom tujuan antar, kalau diisi lewat sana.
  LatLng? _posisiTujuan;

  @override
  void initState() {
    super.initState();

    final contoh = widget.contoh;
    if (contoh != null) {
      _makananController.text = contoh.deskripsi ?? '';
      _belipController.text = contoh.alamatJemput ?? '';
      _tujuanController.text = contoh.alamatTujuan ?? '';
      if (contoh.latitudeJemput != null && contoh.longitudeJemput != null) {
        _posisiBeli = LatLng(contoh.latitudeJemput!, contoh.longitudeJemput!);
      }
      if (contoh.latitudeTujuan != null && contoh.longitudeTujuan != null) {
        _posisiTujuan = LatLng(contoh.latitudeTujuan!, contoh.longitudeTujuan!);
      }
      return;
    }

    final alamat = ref.read(authRepositoryProvider).userAktif?.alamat;
    if (alamat != null && alamat.isNotEmpty) {
      _tujuanController.text = alamat;
    }
  }

  @override
  void dispose() {
    _makananController.dispose();
    _belipController.dispose();
    _tujuanController.dispose();
    _focusMakanan.dispose();
    _focusBeli.dispose();
    _focusTujuan.dispose();
    super.dispose();
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
        data: (tarif) => _buildBody(context, KalkulatorTarif.jastipMakanan(tarif: tarif)),
      ),
      bottomNavigationBar: tarifAsync.maybeWhen(
        data: (tarif) => _BilahBawahGojekMakanan(
          total: KalkulatorTarif.jastipMakanan(tarif: tarif).total,
          sedangMengirim: _sedangMengirim,
          onTekan: _buatOrder,
        ),
        orElse: () => null,
      ),
    );
  }

  Widget _buildBody(BuildContext context, HasilTarif hasil) {
    final user = ref.watch(authRepositoryProvider).userAktif;
    final namaPanggilan = (user?.nama.isNotEmpty == true)
        ? user!.nama.trim().split(' ').first
        : 'Mahasiswa';

    return SafeArea(
      top: false,
      child: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 1. Header Hijau Gojek Aloha
            _buildGojekHeader(context, namaPanggilan),

            const SizedBox(height: 14),

            // 2. Kartu Pesanan Makanan / Minuman & Rekomendasi Cepat
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCardPesananMakanan(),
            ),

            const SizedBox(height: 14),

            // 3. Kartu Rute Terhubung (Warung & Tujuan Antar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildConnectedRouteCard(),
            ),

            const SizedBox(height: 14),

            // 4. Kartu Rincian Ongkos Jasa Aloha
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCardRincianBiaya(hasil),
            ),

            const SizedBox(height: 14),

            // 5. Kartu Edukasi Pembayaran Makanan
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _CardCatatanPembayaran(),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  /// Header hijau Gojek Aloha yang ringkas & elegan
  Widget _buildGojekHeader(BuildContext context, String nama) {
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
                const Text(
                  'Jastip Makanan Kampus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Titip makanan & minuman favoritmu, $nama',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Flat 8rb',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Pesanan Makanan / Minuman dengan Chips Rekomendasi
  Widget _buildCardPesananMakanan() {
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: Color(0xFFEA580C),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PESANAN MAKANAN / MINUMAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEA580C),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Tulis menu, porsi, rasa, atau level pedas secara detail',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextFormField(
              controller: _makananController,
              focusNode: _focusMakanan,
              maxLength: BatasMasukan.deskripsi,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
              validator: _validasiMakanan,
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Rute Terhubung (Warung & Lokasi Pengantaran)
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
          // Titik Warung / Tempat Beli
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
                      'LOKASI WARUNG / KANTIN',
                      style: TextStyle(
                        color: Color(0xFF00AA13),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextFormField(
                      controller: _belipController,
                      focusNode: _focusBeli,
                      maxLength: BatasMasukan.alamat,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _focusTujuan.requestFocus(),
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
                      ),
                      validator: (nilai) => _wajibAlamat(nilai, 'warung'),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _pilihDiPeta,
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

          // Titik Tujuan Pengantaran
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
                      ),
                      validator: (nilai) => _wajibAlamat(nilai, 'tujuan'),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _pilihDiPetaTujuan,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2ED),
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
        ],
      ),
    );
  }

  /// Kartu Rincian Ongkos Jasa Aloha
  Widget _buildCardRincianBiaya(HasilTarif hasil) {
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
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF00AA13),
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'RINCIAN BIAYA JASA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF00AA13),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ongkos Jasa Titip (Delivery)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B5563),
                ),
              ),
              Text(
                formatRupiah(hasil.total),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFFF3F4F6), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Biaya Jasa',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                formatRupiah(hasil.total),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00AA13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _buatOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sedangMengirim = true);

    final Order order;
    try {
      order = await ref
          .read(orderRepositoryProvider)
          .buatOrderJalurA(
            serviceType: ServiceType.jastipMakanan,
            deskripsi: _makananController.text.trim(),
            alamatJemput: _belipController.text.trim(),
            alamatTujuan: _tujuanController.text.trim(),
            latitudeJemput: _posisiBeli?.latitude,
            longitudeJemput: _posisiBeli?.longitude,
            latitudeTujuan: _posisiTujuan?.latitude,
            longitudeTujuan: _posisiTujuan?.longitude,
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

  Future<void> _pilihDiPeta() async {
    final hasil = await Navigator.of(context).push<HasilPilihLokasi>(
      MaterialPageRoute(
        builder: (context) => PemilihLokasiScreen(
          judul: 'Lokasi warung',
          posisiAwal: _posisiBeli,
        ),
      ),
    );
    if (hasil == null || !mounted) return;

    setState(() {
      _belipController.text = hasil.alamat;
      _posisiBeli = hasil.posisi;
    });
  }

  Future<void> _pilihDiPetaTujuan() async {
    final hasil = await Navigator.of(context).push<HasilPilihLokasi>(
      MaterialPageRoute(
        builder: (context) => PemilihLokasiScreen(
          judul: 'Lokasi tujuan antar',
          posisiAwal: _posisiTujuan,
        ),
      ),
    );
    if (hasil == null || !mounted) return;

    setState(() {
      _tujuanController.text = hasil.alamat;
      _posisiTujuan = hasil.posisi;
    });
  }

  static String? _validasiMakanan(String? nilai) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Tulis dulu mau titip apa';
    if (bersih.length < 5) {
      return 'Tulis lebih jelas, runner butuh nama makanan/minuman yang pasti';
    }
    return null;
  }

  static String? _wajibAlamat(String? nilai, String jenis) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Alamat $jenis wajib diisi';
    if (bersih.length < 3) return 'Tulis alamat $jenis lebih jelas';
    return null;
  }
}

/// Banner info pembayaran makanan transparan
class _CardCatatanPembayaran extends StatelessWidget {
  const _CardCatatanPembayaran();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF16A34A),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Harga Makanan Dibayar Saat Serah Terima',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pembayaran digital di aplikasi hanya untuk ongkos jasa titip (Rp 8.000). '
                  'Biaya makanan/minuman dibayarkan langsung secara tunai atau transfer '
                  'ke runner saat pesanan diantar sesuai nota/bon asli warung.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF166534),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bilah bawah berisi total dan tombol buat order ala Gojek Aloha
class _BilahBawahGojekMakanan extends StatelessWidget {
  const _BilahBawahGojekMakanan({
    required this.total,
    required this.sedangMengirim,
    required this.onTekan,
  });

  final int total;
  final bool sedangMengirim;
  final VoidCallback onTekan;

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
                              'Total Biaya Jasa',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            Text(
                              formatRupiah(total),
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Text(
                              'Pesan Jastip',
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
