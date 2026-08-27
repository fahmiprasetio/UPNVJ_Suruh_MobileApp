import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/enums.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/models/order_offer.dart';

/// Penawaran admin untuk order Jalur B, sebagaimana dibaca klien.
///
/// Kartu ini yang membuat harga Jalur B bisa dipertanggungjawabkan: sebelum
/// klien menekan setuju, ia harus melihat berapa harganya, kapan dikerjakan,
/// dan berapa lama. Menyembunyikan salah satunya berarti meminta persetujuan
/// atas sesuatu yang belum diketahui.
class KartuPenawaran extends StatelessWidget {
  const KartuPenawaran({
    super.key,
    required this.order,
    required this.penawaran,
  });

  final Order order;
  final OrderOffer penawaran;

  /// Admin bisa mengusulkan waktu lain dari yang diminta klien, misalnya
  /// karena tim penuh di jam itu. Perbedaan sekecil apa pun harus disebut,
  /// bukan dibiarkan ketahuan sendiri di hari-H.
  bool get _jadwalBergeser =>
      order.jadwalMulai != null &&
      !order.jadwalMulai!.isAtSameMomentAs(penawaran.jadwalMulai);

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final menunggu = penawaran.status == OfferStatus.pending;

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
                    'Penawaran admin',
                    style: teks.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: menunggu ? skema.onPrimaryContainer : null,
                    ),
                  ),
                ),
                Text(
                  penawaran.status.label,
                  style: teks.labelMedium?.copyWith(
                    color: menunggu
                        ? skema.onPrimaryContainer
                        : skema.onSurfaceVariant,
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
                label: 'Catatan admin',
                nilai: penawaran.catatan!,
                menunggu: menunggu,
              ),
            if (_jadwalBergeser) ...[
              const SizedBox(height: AppTheme.spasiKecil),
              Text(
                'Admin mengusulkan waktu lain dari yang kamu minta '
                '(${formatJadwal(order.jadwalMulai!)}).',
                style: teks.bodySmall?.copyWith(
                  color: menunggu
                      ? skema.onPrimaryContainer
                      : skema.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
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
