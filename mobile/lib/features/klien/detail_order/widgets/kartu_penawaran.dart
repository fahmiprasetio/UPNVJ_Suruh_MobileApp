import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/galat_api.dart';
import '../../../../core/config/batas_masukan.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/enums.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/models/order_offer.dart';
import '../../../../providers/repository_providers.dart';

/// Satu penawaran runner untuk order Jalur B, sebagaimana dibaca klien,
/// lengkap dengan tombol setuju/tolak/nego/chat miliknya sendiri.
///
/// Bisa ada beberapa kartu ini berjajar untuk satu order, satu per runner
/// yang menawar, mirip daftar tawaran di aplikasi ojek daring. Karena itu
/// tombol-tombolnya menempel pada kartunya sendiri, bukan di bilah bawah
/// layar: bilah bawah cuma bisa menampung satu tindakan, dan tindakan di sini
/// selalu tentang satu penawaran tertentu, bukan tentang ordernya secara
/// umum.
class KartuPenawaran extends ConsumerStatefulWidget {
  const KartuPenawaran({super.key, required this.order, required this.penawaran});

  final Order order;
  final OrderOffer penawaran;

  @override
  ConsumerState<KartuPenawaran> createState() => _KartuPenawaranState();
}

class _KartuPenawaranState extends ConsumerState<KartuPenawaran> {
  bool _sedangMengirim = false;

  /// Runner ini bisa mengusulkan waktu lain dari yang diminta klien, misalnya
  /// karena sedang ada urusan di jam itu. Perbedaan sekecil apa pun harus
  /// disebut, bukan dibiarkan ketahuan sendiri di hari-H.
  bool get _jadwalBergeser =>
      widget.order.jadwalMulai != null &&
      !widget.order.jadwalMulai!.isAtSameMomentAs(widget.penawaran.jadwalMulai);

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final penawaran = widget.penawaran;
    final order = widget.order;
    final menunggu = penawaran.status == OfferStatus.pending;
    final cocokDenganUsulan =
        order.hargaUsulan != null && order.hargaUsulan == penawaran.harga;

    return Card(
      color: menunggu ? skema.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  size: 18,
                  color: menunggu ? skema.onPrimaryContainer : skema.primary,
                ),
                const SizedBox(width: AppTheme.spasiKecil),
                Expanded(
                  child: Text(
                    cocokDenganUsulan
                        ? 'Runner menyanggupi harga usulanmu'
                        : 'Tawaran runner',
                    style: teks.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: menunggu ? skema.onPrimaryContainer : null,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(
                    Rute.chatOrder(order.id, runnerId: penawaran.runnerId),
                  ),
                  tooltip: 'Chat dengan runner ini',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.forum_outlined,
                    color: menunggu ? skema.onPrimaryContainer : skema.primary,
                  ),
                ),
                if (!menunggu)
                  Text(
                    penawaran.status.label,
                    style: teks.labelMedium?.copyWith(
                      color: skema.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            Text(
              formatRupiah(penawaran.harga),
              style: teks.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: menunggu ? skema.onPrimaryContainer : null,
              ),
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            _BarisPenawaran(
              icon: Icons.event_outlined,
              label: 'Dikerjakan',
              nilai: formatJadwal(penawaran.jadwalMulai),
              menunggu: menunggu,
            ),
            _BarisPenawaran(
              icon: Icons.schedule_outlined,
              label: 'Perkiraan lama',
              nilai: formatDurasi(penawaran.estimasiDurasi),
              menunggu: menunggu,
            ),
            if (penawaran.catatan != null)
              _BarisPenawaran(
                icon: Icons.sticky_note_2_outlined,
                label: 'Catatan runner',
                nilai: penawaran.catatan!,
                menunggu: menunggu,
              ),
            if (_jadwalBergeser) ...[
              const SizedBox(height: AppTheme.spasiKecil),
              Text(
                'Runner mengusulkan waktu lain dari yang kamu minta '
                '(${formatJadwal(order.jadwalMulai!)}).',
                style: teks.bodySmall?.copyWith(
                  color: menunggu
                      ? skema.onPrimaryContainer
                      : skema.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (menunggu) ...[
              const SizedBox(height: AppTheme.spasiSedang),
              _TombolAksi(
                sedangMengirim: _sedangMengirim,
                onSetuju: _setuju,
                onTolak: _tolak,
                onNego: _nego,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setuju() async {
    final berhasil = await _jalankan(
      () => ref
          .read(orderRepositoryProvider)
          .setujuiPenawaran(
            orderId: widget.order.id,
            penawaranId: widget.penawaran.id,
          ),
    );
    if (!berhasil || !mounted) return;
    // Setuju berarti ordernya sudah punya harga dan tinggal dibayar, jadi
    // klien langsung diantar ke layar pembayaran, bukan disuruh mencari
    // tombolnya sendiri.
    context.push(Rute.bayar(widget.order.id));
  }

  Future<void> _tolak() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak tawaran ini?'),
        content: const Text(
          'Tawaran runner ini ditutup. Kalau yang keberatan cuma harganya, '
          'pilih Minta Ditinjau Ulang supaya runner ini bisa menghitung '
          'ulang. Tawaran runner lain (kalau ada) tidak terpengaruh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tolak Tawaran'),
          ),
        ],
      ),
    );
    if (yakin != true) return;

    await _jalankan(
      () => ref
          .read(orderRepositoryProvider)
          .tolakPenawaran(
            orderId: widget.order.id,
            penawaranId: widget.penawaran.id,
          ),
      pesanBerhasil: 'Tawaran ditolak.',
    );
  }

  Future<void> _nego() async {
    final alasan = await showDialog<String>(
      context: context,
      builder: (context) => const _DialogNego(),
    );
    if (alasan == null) return;

    await _jalankan(
      () => ref
          .read(orderRepositoryProvider)
          .ajukanNego(
            orderId: widget.order.id,
            penawaranId: widget.penawaran.id,
            alasan: alasan,
          ),
      pesanBerhasil: 'Alasanmu terkirim ke runner ini lewat chat.',
    );
  }

  Future<bool> _jalankan(
    Future<Order> Function() tindakan, {
    String? pesanBerhasil,
  }) async {
    setState(() => _sedangMengirim = true);
    try {
      await tindakan();
    } catch (galat) {
      if (!mounted) return false;
      setState(() => _sedangMengirim = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi ? galat.pesan : 'Gagal: $galat',
            ),
          ),
        );
      return false;
    }

    if (!mounted) return false;
    setState(() => _sedangMengirim = false);
    if (pesanBerhasil != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(pesanBerhasil)));
    }
    return true;
  }
}

/// Tiga jalan keluar dari sebuah tawaran: setuju, minta ditinjau ulang, atau
/// tolak.
///
/// Ketiganya sengaja tampil sekaligus. Kalau nego disembunyikan di balik
/// menu, klien yang merasa harganya kemahalan akan menekan tolak, dan
/// tawaran yang sebenarnya masih bisa dinego jadi hilang begitu saja.
class _TombolAksi extends StatelessWidget {
  const _TombolAksi({
    required this.sedangMengirim,
    required this.onSetuju,
    required this.onTolak,
    required this.onNego,
  });

  final bool sedangMengirim;
  final VoidCallback onSetuju;
  final VoidCallback onTolak;
  final VoidCallback onNego;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          onPressed: sedangMengirim ? null : onSetuju,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          child: sedangMengirim
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Setuju & Bayar'),
        ),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: sedangMengirim ? null : onNego,
                child: const Text('Minta Ditinjau Ulang'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: sedangMengirim ? null : onTolak,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Tolak'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Nego menuntut alasan, bukan cuma tombol.
///
/// Runner tidak bisa menghitung ulang dari kata "kemahalan" saja, dan tanpa
/// isian ini permintaan tinjau ulang akan berputar-putar lewat chat sebelum
/// sampai ke angka baru.
class _DialogNego extends StatefulWidget {
  const _DialogNego();

  @override
  State<_DialogNego> createState() => _DialogNegoState();
}

class _DialogNegoState extends State<_DialogNego> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Minta ditinjau ulang'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tulis apa yang membuatmu belum setuju. Alasannya masuk ke chat '
            'pribadimu dengan runner ini supaya ia bisa langsung menjawab.',
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          TextField(
            controller: _controller,
            maxLength: BatasMasukan.alasanNego,
            autofocus: true,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Bisa kurang sedikit? Kamarnya kecil.',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Kirim'),
        ),
      ],
    );
  }
}

class _BarisPenawaran extends StatelessWidget {
  const _BarisPenawaran({
    required this.icon,
    required this.label,
    required this.nilai,
    required this.menunggu,
  });

  final IconData icon;
  final String label;
  final String nilai;
  final bool menunggu;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    final warna = menunggu ? skema.onPrimaryContainer : skema.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: warna),
          const SizedBox(width: AppTheme.spasiKecil),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: teks.bodySmall?.copyWith(color: warna),
            ),
          ),
          Expanded(
            child: Text(
              nilai,
              style: teks.bodyMedium?.copyWith(
                color: warna,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
