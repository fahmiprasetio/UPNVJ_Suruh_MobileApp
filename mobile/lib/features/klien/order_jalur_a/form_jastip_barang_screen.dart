import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/config/batas_masukan.dart';
import '../../../core/format/formatters.dart';
import '../../../core/format/jarak.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/models/tarif.dart';
import '../../../domain/pricing/kalkulator_tarif.dart';
import '../../../providers/repository_providers.dart';
import '../../widgets/pesan_kosong.dart';
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
  final _barangController = TextEditingController();
  final _ambilController = TextEditingController();
  final _tujuanController = TextEditingController();
  final _jarakController = TextEditingController();

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
      appBar: AppBar(title: const Text('Jastip Barang')),
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
            TextFormField(
              controller: _barangController,
              maxLength: BatasMasukan.deskripsi,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                counterText: '',
                labelText: 'Barang apa yang dititip?',
                hintText:
                    'Ambil paket di Indomaret Pondok Labu, atas nama Dina',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              validator: _validasiBarang,
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            TextFormField(
              controller: _ambilController,
              maxLength: BatasMasukan.alamat,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                counterText: '',
                labelText: 'Diambil di mana?',
                hintText: 'Indomaret Pondok Labu',
                prefixIcon: Icon(Icons.store_outlined),
              ),
              validator: (nilai) => _wajibAlamat(nilai, 'pengambilan'),
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
            const SizedBox(height: AppTheme.spasiSedang),
            TextFormField(
              controller: _jarakController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                counterText: '',
                labelText: 'Perkiraan jarak',
                suffixText: 'km',
                prefixIcon: Icon(Icons.straighten_outlined),
              ),
              // Cuma kolom ini, bukan seluruh form: tanpa ini, jarak di atas
              // batas dijepit diam-diam di pratinjau harga tanpa penjelasan
              // apa pun sampai "Buat Order" ditekan.
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
            const SizedBox(height: AppTheme.spasiBesar),
            if (hasil == null)
              const _HargaBelumBisaDihitung()
            else ...[
              RingkasanHarga(hasil: hasil),
              const SizedBox(height: AppTheme.spasiKecil),
              const _CatatanHargaBarang(),
            ],
          ],
        ),
      ),
    );
  }

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
            serviceType: ServiceType.jastipBarang,
            // Yang dikirim jaraknya, bukan totalnya, lihat alasannya di kontrak.
            jarakKm: jarak,
            deskripsi: _barangController.text.trim(),
            alamatJemput: _ambilController.text.trim(),
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

class _HargaBelumBisaDihitung extends StatelessWidget {
  const _HargaBelumBisaDihitung();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      decoration: BoxDecoration(
        color: skema.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
      ),
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
    );
  }
}

/// Bilah bawah berisi total dan tombol buat order.
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
