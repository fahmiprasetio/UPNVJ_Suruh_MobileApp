import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/service_catalog.dart';
import '../../../../providers/repository_providers.dart';

/// Lembar penyelesaian order: foto bukti dulu, baru boleh ditandai selesai.
///
/// Foto bukti dibuat wajib, bukan disarankan. Tanpa foto, "selesai" cuma
/// pengakuan runner — dan pengakuan tidak bisa ditunjukkan ke klien yang
/// protes maupun dipakai admin saat menengahi. Urutannya juga disengaja:
/// tombol selesai baru hidup setelah fotonya ada, jadi tidak ada jalan untuk
/// menutup order lebih dulu dan menyusulkan fotonya nanti.
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

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.spasiSedang,
        right: AppTheme.spasiSedang,
        top: AppTheme.spasiSedang,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.spasiSedang,
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
            OutlinedButton.icon(
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
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            )
          else
            _KartuFotoTerkirim(
              url: _fotoBuktiUrl!,
              onGanti: sibuk ? null : _ambilFoto,
            ),
          if (ref.watch(fotoBuktiTiruanProvider)) ...[
            const SizedBox(height: AppTheme.spasiKecil),
            const _CatatanAlatPenguji(),
          ],
          const SizedBox(height: AppTheme.spasiBesar),
          TextField(
            controller: _catatanController,
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
      // `null` berarti runner menutup kamera tanpa memotret — tidak ada yang
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
            runnerId: user.id,
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

class _KartuFotoTerkirim extends StatelessWidget {
  const _KartuFotoTerkirim({required this.url, required this.onGanti});

  final String url;
  final VoidCallback? onGanti;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.check_circle_outline, color: skema.primary),
        title: const Text('Foto bukti terkirim'),
        subtitle: Text(
          url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
        ),
        trailing: TextButton(onPressed: onGanti, child: const Text('Ganti')),
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
            'ALAT PENGUJI — kamera dan penyimpanan foto belum terpasang. '
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
