import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/config/batas_masukan.dart';
import '../../../core/format/formatters.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/pricing/kalkulator_tarif.dart';
import '../../../providers/repository_providers.dart';
import '../../widgets/pesan_kosong.dart';
import '../peta/pemilih_lokasi_screen.dart';
import 'widgets/ringkasan_harga.dart';

/// Form Jalur A untuk Jastip Makanan.
///
/// Menyusul jauh sesudah Anter Jemput dan Jastip Barang, bukan karena lebih
/// sulit dikoding, melainkan karena harga makanan baru pasti setelah runner
/// sampai di warung, sementara sistem menuntut bayar di depan (rencana
/// capstone bagian 14.7a). Yang ternyata sudah menjawabnya lebih dulu adalah
/// `KalkulatorTarif.jastipMakanan`: fee tetap, tidak menerima jarak sama
/// sekali, harga makanannya sendiri dibayar terpisah -- pola yang sama persis
/// dengan yang sudah dipakai Jastip Barang untuk harga barangnya. Layar ini
/// cuma memberi pola yang sudah ada itu sebuah pintu.
///
/// Karena itu tidak ada kalkulator di sini: totalnya sudah pasti sejak layar
/// dibuka, tidak menunggu isian apa pun.
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
  final _makananController = TextEditingController();
  final _belipController = TextEditingController();
  final _tujuanController = TextEditingController();

  bool _sedangMengirim = false;

  /// Titik peta untuk kolom warung, kalau diisi lewat sana.
  ///
  /// Tidak ada kolom jarak di form ini -- tarif Jastip Makanan flat, tidak
  /// menghitung rute -- jadi titiknya cuma dipakai membuka kembali peta di
  /// posisi terakhir, sama sekali tidak dikirim ke server.
  LatLng? _posisiBeli;

  /// Alamat tersimpan mengisi sendiri kolom "Diantar ke mana?", mengikuti
  /// alasan yang sama seperti Jastip Barang: yang dibeli ada di warung, yang
  /// diantar adalah dirinya sendiri.
  ///
  /// Order contoh menang atas alamat tersimpan, dengan alasan yang sama
  /// seperti form Jalur A lainnya.
  @override
  void initState() {
    super.initState();

    final contoh = widget.contoh;
    if (contoh != null) {
      _makananController.text = contoh.deskripsi ?? '';
      _belipController.text = contoh.alamatJemput ?? '';
      _tujuanController.text = contoh.alamatTujuan ?? '';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tarifAsync = ref.watch(tarifProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Jastip Makanan')),
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
        data: (tarif) =>
            _buildForm(context, KalkulatorTarif.jastipMakanan(tarif: tarif)),
      ),
      bottomNavigationBar: tarifAsync.maybeWhen(
        data: (tarif) => _BilahBuatOrder(
          total: KalkulatorTarif.jastipMakanan(tarif: tarif).total,
          sedangMengirim: _sedangMengirim,
          onTekan: _buatOrder,
        ),
        orElse: () => null,
      ),
    );
  }

  Widget _buildForm(BuildContext context, HasilTarif hasil) {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spasiSedang),
          children: [
            TextFormField(
              controller: _makananController,
              maxLength: BatasMasukan.deskripsi,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                counterText: '',
                labelText: 'Makanan/minuman apa yang mau dititip?',
                hintText: 'Ayam geprek level 2 + es teh manis',
                prefixIcon: Icon(Icons.lunch_dining_outlined),
              ),
              validator: _validasiMakanan,
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            TextFormField(
              controller: _belipController,
              maxLength: BatasMasukan.alamat,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                counterText: '',
                labelText: 'Beli di mana?',
                hintText: 'Warung Bu Yati',
                prefixIcon: const Icon(Icons.store_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map_outlined),
                  tooltip: 'Pilih di peta',
                  onPressed: _pilihDiPeta,
                ),
              ),
              validator: (nilai) => _wajibAlamat(nilai, 'warung'),
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            TextFormField(
              controller: _tujuanController,
              maxLength: BatasMasukan.alamat,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                counterText: '',
                labelText: 'Diantar ke mana?',
                hintText: 'Kos Melati kamar 7',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (nilai) => _wajibAlamat(nilai, 'tujuan'),
            ),
            const SizedBox(height: AppTheme.spasiBesar),
            RingkasanHarga(hasil: hasil),
            const SizedBox(height: AppTheme.spasiKecil),
            const _CatatanHargaMakanan(),
          ],
        ),
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
          );
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMengirim = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Order gagal dibuat: $galat')));
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

  static String? _validasiMakanan(String? nilai) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Tulis dulu mau titip apa';
    if (bersih.length < 10) {
      return 'Tulis lebih jelas, runner tidak bisa menebak pesanannya';
    }
    return null;
  }

  static String? _wajibAlamat(String? nilai, String jenis) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Alamat $jenis wajib diisi';
    if (bersih.length < 5) return 'Tulis alamat $jenis lebih jelas';
    return null;
  }
}

/// Pengakuan bahwa yang dibayar di aplikasi baru ongkos jasanya, bukan
/// harga makanannya -- sama seperti Jastip Barang, cuma bicara soal makanan.
class _CatatanHargaMakanan extends StatelessWidget {
  const _CatatanHargaMakanan();

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
            'Harga makanannya belum termasuk. Yang kamu bayar sekarang ongkos '
            'jasa titip, harga makanan dan minuman dibayar tunai langsung ke '
            'runner saat serah terima.',
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
///
/// Totalnya selalu ada sejak layar dibuka -- fee tetap, tidak menunggu isian
/// apa pun -- jadi tombolnya cuma mati selagi form sedang mengirim, bukan
/// menunggu harga bisa dihitung seperti di Anter Jemput dan Jastip Barang.
class _BilahBuatOrder extends StatelessWidget {
  const _BilahBuatOrder({
    required this.total,
    required this.sedangMengirim,
    required this.onTekan,
  });

  final int total;
  final bool sedangMengirim;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total bayar',
                    style: teks.bodySmall?.copyWith(
                      color: skema.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatRupiah(total),
                    style: teks.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: skema.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spasiSedang),
            SizedBox(
              width: 180,
              child: FilledButton(
                onPressed: sedangMengirim ? null : onTekan,
                child: sedangMengirim
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Buat Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
