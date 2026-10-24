import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/api/idempotency_key.dart';
import '../../../core/config/batas_masukan.dart';
import '../../../core/format/formatters.dart';
import '../../../core/format/jarak.dart';
import '../../../core/peta/jarak_rute.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/models/tarif.dart';
import '../../../domain/pricing/kalkulator_tarif.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/widgets/pesan_kosong.dart';
import '../peta/pemilih_lokasi_screen.dart';
import 'widgets/ringkasan_harga.dart';

/// Form Jalur A untuk Jastip Barang.
///
/// Bedanya dengan Anter Jemput bukan cuma isian: di sini ada barang yang
/// dititipkan, dan harga barang itu belum tentu diketahui saat order dibuat.
/// Karena aturan bayar di depan belum bisa dipertemukan dengan harga barang
/// yang belum pasti (rencana capstone bagian 14.7a), yang ditagih aplikasi
/// untuk sekarang hanya ongkos jasanya, dan itu dikatakan terus terang di
/// layar, bukan disembunyikan di catatan kaki.
class FormJastipBarangScreen extends ConsumerStatefulWidget {
  const FormJastipBarangScreen({super.key, this.contoh});

  /// Order lama yang isinya dipakai mengisi form ini di muka ("Pesan lagi"),
  /// dan null untuk form kosong seperti biasa.
  final Order? contoh;

  @override
  ConsumerState<FormJastipBarangScreen> createState() =>
      _FormJastipBarangScreenState();
}

class _FormJastipBarangScreenState
    extends ConsumerState<FormJastipBarangScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _idempotencyKey = buatIdempotencyKey();
  final _barangController = TextEditingController();
  final _ambilController = TextEditingController();
  final _tujuanController = TextEditingController();
  final _jarakController = TextEditingController();

  LatLng? _posisiAmbil;
  LatLng? _posisiTujuan;
  bool _sedangHitungRute = false;
  bool _sedangMengirim = false;

  /// Alamat tersimpan mengisi sendiri kolom "Diantar ke mana?".
  ///
  /// Yang diisi cuma satu dari dua kolom alamat di layar ini, dan yang mana
  /// bukan pilihan sembarang: di jastip barang, yang diambil ada di toko dan yang diantar adalah dirinya sendiri.
  ///
  /// Diisi, bukan ditawarkan lewat tombol "pakai alamat saya". Isinya terlihat,
  /// bisa disunting, dan tetap divalidasi sebelum dikirim, jadi tombol tambahan
  /// cuma menambah satu ketukan bagi orang yang memang memesan dari kosnya --
  /// yaitu hampir semuanya.
  ///
  /// Dibaca sekali di sini lewat `userAktif`, bukan ditonton lewat provider:
  /// alamat yang berubah di tengah orang mengetik formulir order tidak boleh
  /// menimpa apa yang sudah ia ketik.
  ///
  /// Order contoh menang atas alamat tersimpan, dengan alasan yang sama seperti
  /// di form anter jemput.
  @override
  void initState() {
    super.initState();

    final contoh = widget.contoh;
    if (contoh != null) {
      _barangController.text = contoh.deskripsi ?? '';
      _ambilController.text = contoh.alamatJemput ?? '';
      _tujuanController.text = contoh.alamatTujuan ?? '';
      _jarakController.text = tulisJarak(contoh.jarakKm);
      return;
    }

    final alamat = ref.read(authRepositoryProvider).userAktif?.alamat;
    if (alamat != null && alamat.isNotEmpty) {
      _tujuanController.text = alamat;
    }
  }

  @override
  void dispose() {
    _barangController.dispose();
    _ambilController.dispose();
    _tujuanController.dispose();
    _jarakController.dispose();
    super.dispose();
  }

  /// `null` selama jarak belum diisi dengan angka yang masuk akal.
  HasilTarif? _hasilTarif(Tarif tarif) {
    final jarak = bacaJarak(_jarakController.text);
    if (jarak == null) return null;
    return KalkulatorTarif.jastipBarang(jarakKm: jarak, tarif: tarif);
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
        data: (tarif) => _buildForm(context, tarif),
      ),
      bottomNavigationBar: tarifAsync.maybeWhen(
        data: (tarif) {
          final jarak = bacaJarak(_jarakController.text);
          final melebihiBatas =
              jarak != null && jarak > tarif.anjemJarakMaksimalKm;
          final hasil = melebihiBatas ? null : _hasilTarif(tarif);
          return _BilahBuatOrder(
            total: melebihiBatas ? null : hasil?.total,
            sedangMengirim: _sedangMengirim,
            onTekan: melebihiBatas ? null : _buatOrder,
            melebihiBatas: melebihiBatas,
            batasMaksimalKm: tarif.anjemJarakMaksimalKm.round(),
          );
        },
        orElse: () => null,
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
                  'Jastip Barang Kampus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Titip bawa & kirim barang kebutuhanmu, $nama',
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

  /// Kartu Barang yang Dititipkan
  Widget _buildBarangCard() {
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
                  Icons.inventory_2_outlined,
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
                      'BARANG YANG DITITIP',
                      style: TextStyle(
                        color: Color(0xFF00AA13),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tulis nama dan rincian barang',
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
            controller: _barangController,
            maxLength: BatasMasukan.deskripsi,
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
              hintText: 'Nama barang yang dititipkan',
            ),
            validator: _validasiBarang,
          ),
        ],
      ),
    );
  }

  /// Kartu Rute Terhubung (Ambil & Antar)
  Widget _buildConnectedRouteCard(Tarif tarif, bool melebihiBatas) {
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
          // Titik Ambil
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
                      'TITIK PENGAMBILAN',
                      style: TextStyle(
                        color: Color(0xFF00AA13),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextFormField(
                      controller: _ambilController,
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
                        hintText: 'Titik pengambilan barang',
                        hintStyle: TextStyle(
                          color: Color(0xFF9EA8A0),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      validator: (nilai) => _wajibAlamat(nilai, 'pengambilan'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              InkWell(
                onTap: () => _pilihDiPeta(
                  controller: _ambilController,
                  judul: 'Titik pengambilan barang',
                  untukAmbil: true,
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

          // Titik Antar / Tujuan
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
                      'TITIK PENGANTARAN',
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
                        hintText: 'Titik tujuan pengantaran',
                        hintStyle: TextStyle(
                          color: Color(0xFF9EA8A0),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      validator: (nilai) => _wajibAlamat(nilai, 'tujuan'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              InkWell(
                onTap: () => _pilihDiPeta(
                  controller: _tujuanController,
                  judul: 'Titik tujuan pengantaran',
                  untukAmbil: false,
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

  Widget _buildForm(BuildContext context, Tarif tarif) {
    final jarak = bacaJarak(_jarakController.text);
    final melebihiBatas = jarak != null && jarak > tarif.anjemJarakMaksimalKm;
    final hasil = melebihiBatas ? null : _hasilTarif(tarif);
    final user = ref.watch(authRepositoryProvider).userAktif;
    final namaPanggilan = user?.nama.split(' ').first ?? 'Kak';

    return Form(
      key: _formKey,
      onChanged: () => setState(() {}),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. Header Gojek Aloha
          _buildGojekHeader(context, namaPanggilan),

          const SizedBox(height: 14),

          // 2. Kartu Barang yang Dititip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildBarangCard(),
          ),

          const SizedBox(height: 14),

          // 3. Kartu Rute Terhubung (Ambil & Antar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildConnectedRouteCard(tarif, melebihiBatas),
          ),

          const SizedBox(height: 14),

          // 4. Ringkasan Tarif / Peringatan Batas Jarak
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
          else if (hasil != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RingkasanHarga(hasil: hasil),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _CatatanHargaBarang(),
            ),
          ],

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Future<void> _buatOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final jarak = bacaJarak(_jarakController.text);
    if (jarak == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Pilih titik pengambilan dan tujuan di peta untuk menentukan rute.',
            ),
          ),
        );
      return;
    }

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
            serviceType: ServiceType.jastipBarang,
            // Yang dikirim jaraknya, bukan totalnya, lihat alasannya di kontrak.
            jarakKm: jarak,
            deskripsi: _barangController.text.trim(),
            alamatJemput: _ambilController.text.trim(),
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

  static String? _validasiBarang(String? nilai) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Tulis dulu barang yang mau dititip';
    if (bersih.length < 10) {
      return 'Tulis lebih jelas, runner tidak bisa menebak barangnya';
    }
    return null;
  }

  static String? _wajibAlamat(String? nilai, String jenis) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Alamat $jenis wajib diisi';
    if (bersih.length < 5) return 'Tulis alamat $jenis lebih jelas';
    return null;
  }

  /// Membuka pemilih peta untuk satu kolom alamat, dan mengisi kolom jarak
  /// otomatis begitu titik ambil maupun tujuan sudah sama-sama punya koordinat.
  Future<void> _pilihDiPeta({
    required TextEditingController controller,
    required String judul,
    required bool untukAmbil,
  }) async {
    final posisiSekarang = untukAmbil ? _posisiAmbil : _posisiTujuan;
    final hasil = await Navigator.of(context).push<HasilPilihLokasi>(
      MaterialPageRoute(
        builder: (context) =>
            PemilihLokasiScreen(judul: judul, posisiAwal: posisiSekarang),
      ),
    );
    if (hasil == null || !mounted) return;

    controller.text = hasil.alamat;
    setState(() {
      if (untukAmbil) {
        _posisiAmbil = hasil.posisi;
      } else {
        _posisiTujuan = hasil.posisi;
      }
    });

    final ambil = _posisiAmbil;
    final tujuan = _posisiTujuan;
    if (ambil == null || tujuan == null) return;

    setState(() => _sedangHitungRute = true);
    double? jarakFinal;
    try {
      final km = await JarakRuteOsrm.kilometer(ambil, tujuan);
      if (km != null && km > 0) {
        jarakFinal = double.parse(km.toStringAsFixed(1));
      }
    } catch (_) {}

    if (jarakFinal == null) {
      final meter = const Distance().as(LengthUnit.Meter, ambil, tujuan);
      final perkiraanKm = (meter / 1000.0) * 1.25;
      final finalKm = (perkiraanKm < 0.3) ? 0.5 : perkiraanKm;
      jarakFinal = double.parse(finalKm.toStringAsFixed(1));
    }

    if (!mounted) return;
    setState(() {
      _sedangHitungRute = false;
      _jarakController.text = tulisJarak(jarakFinal!);
    });
  }
}

/// Pengakuan bahwa yang dibayar di aplikasi baru ongkos jasanya.
class _CatatanHargaBarang extends StatelessWidget {
  const _CatatanHargaBarang();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: skema.onSurfaceVariant),
        const SizedBox(width: AppTheme.spasiKecil),
        Expanded(
          child: Text(
            'Harga barangnya belum termasuk. Yang kamu bayar sekarang ongkos '
            'jasa titip, harga barang diselesaikan langsung dengan runner.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Bilah bawah berisi total dan tombol buat order.
class _BilahBuatOrder extends StatelessWidget {
  const _BilahBuatOrder({
    required this.total,
    required this.sedangMengirim,
    required this.onTekan,
    this.melebihiBatas = false,
    this.batasMaksimalKm = 15,
  });

  final int? total;
  final bool sedangMengirim;
  final VoidCallback? onTekan;
  final bool melebihiBatas;
  final int batasMaksimalKm;

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
                                  : (melebihiBatas
                                        ? 'Di Luar Batas'
                                        : 'Pilih Rute'),
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
                              melebihiBatas
                                  ? 'Maks. $batasMaksimalKm km'
                                  : 'Buat Order',
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
