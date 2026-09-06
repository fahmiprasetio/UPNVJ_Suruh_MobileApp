import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/config/batas_masukan.dart';
import '../../../core/router/app_router.dart';
import '../../../core/format/formatters.dart';
import '../../../core/format/jarak.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/models/tarif.dart';
import '../../../domain/pricing/kalkulator_tarif.dart';
import '../../../providers/repository_providers.dart';
import '../../widgets/pesan_kosong.dart';
import 'widgets/ringkasan_harga.dart';

/// Form Jalur A untuk Anter Jemput.
///
/// Ciri Jalur A: harga sudah pasti sebelum order dibuat, jadi klien melihat
/// totalnya berubah langsung sambil mengisi, tidak ada fase menunggu
/// penawaran (rencana capstone bagian 3).
class FormAnterJemputScreen extends ConsumerStatefulWidget {
  const FormAnterJemputScreen({super.key});

  @override
  ConsumerState<FormAnterJemputScreen> createState() =>
      _FormAnterJemputScreenState();
}

class _FormAnterJemputScreenState extends ConsumerState<FormAnterJemputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jemputController = TextEditingController();
  final _tujuanController = TextEditingController();
  final _jarakController = TextEditingController();
  final _catatanController = TextEditingController();

  bool _sedangMengirim = false;

  /// Alamat tersimpan mengisi sendiri kolom "Dijemput di mana?".
  ///
  /// Yang diisi cuma satu dari dua kolom alamat di layar ini, dan yang mana
  /// bukan pilihan sembarang: di anter jemput justru terbalik dari jastip barang, karena yang dijemput adalah dirinya sendiri dan yang dituju kampus atau tempat lain.
  ///
  /// Diisi, bukan ditawarkan lewat tombol "pakai alamat saya". Isinya terlihat,
  /// bisa disunting, dan tetap divalidasi sebelum dikirim, jadi tombol tambahan
  /// cuma menambah satu ketukan bagi orang yang memang memesan dari kosnya --
  /// yaitu hampir semuanya.
  ///
  /// Dibaca sekali di sini lewat `userAktif`, bukan ditonton lewat provider:
  /// alamat yang berubah di tengah orang mengetik formulir order tidak boleh
  /// menimpa apa yang sudah ia ketik.
  @override
  void initState() {
    super.initState();
    final alamat = ref.read(authRepositoryProvider).userAktif?.alamat;
    if (alamat != null && alamat.isNotEmpty) {
      _jemputController.text = alamat;
    }
  }

  @override
  void dispose() {
    _jemputController.dispose();
    _tujuanController.dispose();
    _jarakController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  /// `null` selama jarak belum diisi dengan angka yang masuk akal, harga
  /// memang belum bisa dihitung, dan menampilkan Rp 0 akan menyesatkan.
  HasilTarif? _hasilTarif(Tarif tarif) {
    final jarak = bacaJarak(_jarakController.text);
    if (jarak == null) return null;
    return KalkulatorTarif.anterJemput(jarakKm: jarak, tarif: tarif);
  }

  @override
  Widget build(BuildContext context) {
    final tarifAsync = ref.watch(tarifProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Anter Jemput')),
      // Tarif diambil sekali dari server (tarifProvider), bukan dihitung dari
      // konstanta yang ditulis mati di aplikasi: admin bisa mengubahnya lewat
      // dashboard web, dan pratinjau harga di sini harus mengikuti angka yang
      // sedang berlaku, bukan angka yang ikut ter-commit bertahun-tahun lalu.
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
        // Belum ada tarif untuk dihitung: bilah bawah ikut hilang sampai
        // tarifnya berhasil dimuat, sama seperti tombolnya mati saat harga
        // belum bisa dihitung.
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
              controller: _jemputController,
              maxLength: BatasMasukan.alamat,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                counterText: '',
                labelText: 'Dijemput di mana?',
                hintText: 'Kos Melati, Jl. Pondok Labu Raya No. 12',
                prefixIcon: Icon(Icons.my_location_outlined),
              ),
              validator: (nilai) => _wajibAlamat(nilai, 'jemput'),
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
                hintText: 'Gedung Fakultas Ilmu Komputer UPNVJ',
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
            // Yang dikirim jaraknya, bukan totalnya. Angka di layar tadi cuma
            // rincian yang dilihat klien sebelum memesan; yang mengikat adalah
            // hitungan server.
            jarakKm: jarak,
            deskripsi: _catatanController.text.trim().isEmpty
                ? null
                : _catatanController.text.trim(),
            alamatJemput: _jemputController.text.trim(),
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

    // Form diganti, bukan ditumpuk: menekan kembali dari detail order
    // sebaiknya pulang ke beranda, bukan balik ke form yang sudah terkirim.
    context.pushReplacement(Rute.detailOrder(order.id));
  }

  static String? _wajibAlamat(String? nilai, String jenis) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Alamat $jenis wajib diisi';
    if (bersih.length < 5) return 'Tulis alamat $jenis lebih jelas';
    return null;
  }

}

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
                    // Hijau, sama seperti total di kartu ringkasan.
                    //
                    // Angkanya sama persis, jadi ia harus terlihat sama persis.
                    // Dua perlakuan berbeda untuk satu fakta membuat orang
                    // memeriksa apakah keduanya memang angka yang sama, dan itu
                    // pekerjaan yang tidak perlu ada.
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
