import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/service_catalog.dart';

/// Satu order yang dipegang runner.
///
/// Bentuknya berubah menurut keadaan order: yang sedang dikerjakan menawarkan
/// tindakan, yang sudah selesai memperlihatkan bukti yang tertinggal. Kartu
/// ini tidak pernah kosong tindakan sekaligus kosong keterangan.
class KartuOrderRunner extends StatelessWidget {
  const KartuOrderRunner({
    super.key,
    required this.order,
    this.onSelesaikan,
  });

  final Order order;

  /// `null` untuk order yang sudah selesai — tidak ada lagi yang bisa
  /// dilakukan runner terhadapnya.
  final VoidCallback? onSelesaikan;

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(order.serviceType);
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(layanan.icon, size: 20, color: skema.onSurfaceVariant),
                const SizedBox(width: AppTheme.spasiKecil),
                Expanded(
                  child: Text(
                    layanan.nama,
                    style: teks.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  formatRupiah(order.harga),
                  style: teks.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: skema.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spasiKecil),
            Text(
              '${order.kodeOrder} · ${order.namaKlien}',
              style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
            ),
            if (order.alamatTujuan != null) ...[
              const SizedBox(height: AppTheme.spasiKecil),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: skema.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.spasiKecil),
                  Expanded(
                    child: Text(order.alamatTujuan!, style: teks.bodySmall),
                  ),
                ],
              ),
            ],
            if (order.deskripsi != null) ...[
              const SizedBox(height: AppTheme.spasiKecil),
              Text(order.deskripsi!, style: teks.bodyMedium),
            ],
            const SizedBox(height: AppTheme.spasiSedang),
            if (onSelesaikan != null)
              FilledButton.icon(
                onPressed: onSelesaikan,
                icon: const Icon(Icons.task_alt_outlined),
                label: const Text('Selesaikan Order'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              )
            else
              _RingkasanPenyelesaian(order: order),
          ],
        ),
      ),
    );
  }
}

/// Jejak yang tertinggal setelah order ditutup: kapan, bukti apa, pesan apa.
class _RingkasanPenyelesaian extends StatelessWidget {
  const _RingkasanPenyelesaian({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: skema.primary),
            const SizedBox(width: AppTheme.spasiKecil),
            Expanded(
              child: Text(
                order.selesaiPada == null
                    ? 'Selesai'
                    : 'Selesai ${formatTanggalJam(order.selesaiPada!)}',
                style: teks.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (order.fotoBuktiUrl != null) ...[
          const SizedBox(height: 4),
          Text(
            'Foto bukti tersimpan',
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
        ],
        if (order.catatanSerahTerima != null) ...[
          const SizedBox(height: 4),
          Text(
            'Catatan: ${order.catatanSerahTerima!}',
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
