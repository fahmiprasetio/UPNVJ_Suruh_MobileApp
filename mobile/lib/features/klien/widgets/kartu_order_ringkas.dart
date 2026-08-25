import 'package:flutter/material.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/order.dart';
import '../../../domain/service_catalog.dart';
import 'lencana_status.dart';

/// Satu baris order di daftar riwayat.
class KartuOrderRingkas extends StatelessWidget {
  const KartuOrderRingkas({
    super.key,
    required this.order,
    required this.onTap,
  });

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(order.serviceType);
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                  LencanaStatus(status: order.status),
                ],
              ),
              const SizedBox(height: AppTheme.spasiKecil),
              Text(
                '${order.kodeOrder} · ${formatWaktuRelatif(order.dibuatPada)}',
                style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
              ),
              if (order.deskripsi != null) ...[
                const SizedBox(height: 2),
                Text(
                  order.deskripsi!,
                  style: teks.bodySmall?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppTheme.spasiKecil),
              Text(
                // Harga Jalur B memang belum ada sebelum penawaran disepakati;
                // itu keadaan yang sah, bukan data hilang.
                order.harga == null
                    ? 'Harga menunggu penawaran'
                    : formatRupiah(order.harga),
                style: teks.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: order.harga == null ? skema.onSurfaceVariant : skema.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
