import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/batas_masukan.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/service_catalog.dart';
import '../../../../providers/repository_providers.dart';

/// Lembar penyelesaian order: foto bukti dulu, baru boleh ditandai selesai.
///
/// Foto bukti dibuat wajib, bukan disarankan. Tanpa foto, "selesai" cuma
/// pengakuan runner, dan pengakuan tidak bisa ditunjukkan ke klien yang
/// protes maupun dipakai admin saat menengahi. Urutannya juga disengaja:
/// tombol selesai baru hidup setelah fotonya ada, jadi tidak ada jalan untuk
/// menutup order lebih dulu dan menyusulkan fotonya nanti.
///
/// ## Yang maroon selalu langkah yang sedang hidup
///
/// Sebelumnya tombol foto bergaris tipis dan tombol Tandai Selesai maroon
/// selebar lembar, padahal saat lembar ini baru dibuka yang bisa dilakukan
/// justru cuma memotret: Tandai Selesai mati sampai fotonya ada. Yang paling
/// keras bicara adalah tombol yang tidak bisa ditekan, dan yang harus ditekan
/// tampil seperti pilihan sampingan. Runner yang menekan tombol besar lalu
/// tidak terjadi apa-apa akan menyimpulkan aplikasinya rusak, bukan bahwa ada
/// syarat yang belum ia penuhi.
///
/// Sekarang maroonnya berpindah mengikuti langkah yang sedang hidup: tombol
/// foto selagi fotonya belum ada, Tandai Selesai setelah ada. Dua tombol maroon
/// tidak pernah hidup bersamaan di lembar ini.
///
/// Mengembalikan `true` lewat [Navigator.pop] kalau order berhasil ditutup.
class LembarSelesaikanOrder extends ConsumerStatefulWidget {
  const LembarSelesaikanOrder({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<LembarSelesaikanOrder> createState() =>
      _LembarSelesaikanOrderState();
}

class _LembarSelesaikanOrderState extends ConsumerState<LembarSelesaikanOrder> {
  final _catatanController = TextEditingController();

  String? _fotoBuktiUrl;
  bool _sedangAmbilFoto = false;
  bool _sedangMenutup = false;

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(widget.order.serviceType);
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final sibuk = _sedangAmbilFoto || _sedangMenutup;

    // Bisa digulung, karena papan ketik yang terbuka untuk kolom catatan
    // memakan separuh layar ponsel pendek dan sisanya tidak cukup memuat
    // lembar ini utuh. Tanpa ini yang muncul adalah pita luber kuning-hitam
    // tepat saat runner mulai mengetik.
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppTheme.spasiSedang,
        right: AppTheme.spasiSedang,
        top: AppTheme.spasiKecil,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.spasiBesar,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selesaikan ${layanan.nama}',
            style: teks.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            widget.order.kodeOrder,
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spasiBesar),
          Text(
            'Foto bukti',
            style: teks.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Wajib. Inilah yang membedakan pekerjaan selesai dari pengakuan '
            'selesai.',
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          if (_fotoBuktiUrl == null)
            FilledButton.icon(
              onPressed: sibuk ? null : _ambilFoto,
              icon: _sedangAmbilFoto
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_outlined),
              label: Text(
                _sedangAmbilFoto ? 'Mengunggah foto...' : 'Ambil Foto Bukti',
              ),
            )
          else
            _KartuFotoTerkirim(onGanti: sibuk ? null : _ambilFoto),
          if (ref.watch(fotoBuktiTiruanProvider)) ...[
            const SizedBox(height: AppTheme.spasiKecil),
            const _CatatanAlatPenguji(),
          ],
          const SizedBox(height: AppTheme.spasiBesar),
          TextField(
            controller: _catatanController,
            maxLength: BatasMasukan.catatanSerahTerima,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            minLines: 2,
            enabled: !sibuk,
            decoration: const InputDecoration(
              labelText: 'Catatan serah terima (boleh dikosongkan)',
              hintText: 'Barang dititipkan ke penjaga kos',
            ),
          ),
          const SizedBox(height: AppTheme.spasiBesar),
          FilledButton(
            onPressed: _fotoBuktiUrl == null || sibuk ? null : _tandaiSelesai,
            child: _sedangMenutup
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tandai Selesai'),
          ),
        ],
      ),
    );
  }

  Future<void> _ambilFoto() async {
    setState(() => _sedangAmbilFoto = true);

    final String? url;
    try {
      url = await ref
          .read(fotoBuktiRepositoryProvider)
          .ambilDanUnggah(orderId: widget.order.id);
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangAmbilFoto = false);
      _kabari('Foto gagal diunggah: $galat');
      return;
    }

    if (!mounted) return;
    setState(() {
      _sedangAmbilFoto = false;
      // `null` berarti runner menutup kamera tanpa memotret, tidak ada yang
      // perlu dikabarkan, keadaannya cuma kembali seperti semula.
      if (url != null) _fotoBuktiUrl = url;
    });
  }

  Future<void> _tandaiSelesai() async {
    final fotoBuktiUrl = _fotoBuktiUrl;
    final user = ref.read(userAktifProvider).value;
    if (fotoBuktiUrl == null || user == null) return;

    setState(() => _sedangMenutup = true);

    final catatan = _catatanController.text.trim();
    try {
      await ref
          .read(orderRepositoryProvider)
          .selesaikanOrder(
            orderId: widget.order.id,
            fotoBuktiUrl: fotoBuktiUrl,
            catatanSerahTerima: catatan.isEmpty ? null : catatan,
          );
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMenutup = false);
      _kabari('Order gagal ditutup: $galat');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _kabari(String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }
}

/// Bukti yang sudah aman di server, dan satu-satunya jalan menggantinya.
///
/// Hijau, bukan maroon: ini pernyataan bahwa satu syarat sudah terpenuhi, dan
/// hijau di sistem ini memang berarti sesuatu yang sudah benar. Begitu kartu
/// ini muncul, maroon pindah ke Tandai Selesai di bawahnya.
///
/// Yang ditulis di bawah judul bukan lagi alamat berkasnya. Tautan mentah tidak
/// menjawab satu pun pertanyaan yang mungkin dipunyai runner tentang fotonya,
/// dan yang ia butuhkan cuma tahu bahwa fotonya sudah aman dan bisa diganti
/// kalau salah.
class _KartuFotoTerkirim extends StatelessWidget {
  const _KartuFotoTerkirim({required this.onGanti});

  final VoidCallback? onGanti;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spasiKecil + 4),
      decoration: BoxDecoration(
        color: skema.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: skema.onPrimaryContainer),
          const SizedBox(width: AppTheme.spasiKecil + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto bukti terkirim',
                  style: teks.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: skema.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Tersimpan di server, ikut tercatat di order ini.',
                  style: teks.bodySmall?.copyWith(
                    color: skema.onPrimaryContainer.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onGanti,
            style: TextButton.styleFrom(
              foregroundColor: skema.onPrimaryContainer,
            ),
            child: const Text('Ganti'),
          ),
        ],
      ),
    );
  }
}

/// Pengakuan bahwa fotonya belum sungguhan, sepola panel simulator pembayaran.
class _CatatanAlatPenguji extends StatelessWidget {
  const _CatatanAlatPenguji();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.science_outlined, size: 16, color: skema.error),
        const SizedBox(width: AppTheme.spasiKecil),
        Expanded(
          child: Text(
            'ALAT PENGUJI: kamera dan penyimpanan foto belum terpasang. '
            'Tombol ini menghasilkan tautan tiruan, bukan foto sungguhan.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: skema.error),
          ),
        ),
      ],
    );
  }
}
