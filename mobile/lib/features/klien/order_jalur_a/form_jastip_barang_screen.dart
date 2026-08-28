import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/batas_masukan.dart';

import '../../../core/config/tarif_config.dart';
import '../../../core/format/formatters.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/pricing/kalkulator_tarif.dart';
import '../../../providers/repository_providers.dart';
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
  const FormJastipBarangScreen({super.key});

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

  @override
  void dispose() {
    _barangController.dispose();
    _ambilController.dispose();
    _tujuanController.dispose();
    _jarakController.dispose();
    super.dispose();
  }

  /// `null` selama jarak belum diisi dengan angka yang masuk akal.
  HasilTarif? get _hasilTarif {
    final jarak = _bacaJarak(_jarakController.text);
    if (jarak == null) return null;
    return KalkulatorTarif.jastipBarang(jarakKm: jarak);
  }

  @override
  Widget build(BuildContext context) {
    final hasil = _hasilTarif;
    final skema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Jastip Barang')),
      body: SafeArea(
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
                  labelText: 'Perkiraan jarak',
                  suffixText: 'km',
                  prefixIcon: Icon(Icons.straighten_outlined),
                ),
                validator: _validasiJarak,
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
      ),
      bottomNavigationBar: _BilahBuatOrder(
        total: hasil?.total,
        sedangMengirim: _sedangMengirim,
        onTekan: hasil == null ? null : _buatOrder,
      ),
    );
  }

  Future<void> _buatOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final jarak = _bacaJarak(_jarakController.text);
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
      ..showSnackBar(SnackBar(content: Text('Order ${order.kodeOrder} dibuat')));

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

  static String? _validasiJarak(String? nilai) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Perkiraan jarak wajib diisi';
    final jarak = _bacaJarak(bersih);
    if (jarak == null) return 'Isi dengan angka, misalnya 2,5';
    if (jarak > TarifConfig.anjemJarakMaksimalKm) {
      return 'Di atas ${TarifConfig.anjemJarakMaksimalKm.round()} km belum '
          'dilayani, pakai Permintaan Lain';
    }
    return null;
  }

  /// Menerima koma maupun titik sebagai pemisah desimal.
  static double? _bacaJarak(String teks) {
    final angka = double.tryParse(teks.trim().replaceAll(',', '.'));
    if (angka == null || angka <= 0) return null;
    return angka;
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
