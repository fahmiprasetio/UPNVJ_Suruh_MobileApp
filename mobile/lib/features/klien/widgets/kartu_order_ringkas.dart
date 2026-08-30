import 'package:flutter/material.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/order.dart';
import '../../../domain/service_catalog.dart';
import 'lencana_status.dart';

/// Satu baris order di daftar riwayat.
///
/// ## Harganya yang paling keras bicara
///
/// Sebelum ini harga ditulis seukuran nama layanan dan diletakkan paling bawah,
/// jadi yang paling menonjol di kartu justru nama layanan, hal yang sudah
/// diketahui pemesannya sebelum ia membuka daftar. Yang ia buka daftar ini untuk
/// mencarinya adalah angkanya.
///
/// Sekarang harga jadi elemen terbesar dan tertebal di kartu, dengan warna hijau
/// lencana karena hijau di sistem ini berarti sesuatu yang sudah pasti. Nama
/// layanan dan kode order turun jadi keterangan.
class KartuOrderRingkas extends StatelessWidget {
  const KartuOrderRingkas({super.key, required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(order.serviceType);
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    // Harga yang belum ada bukan data hilang, melainkan keadaan yang sah: order
    // Jalur B memang belum punya angka sebelum penawaran admin disepakati.
    // Karena itu ia ditulis sebesar harga sungguhan, bukan diringkas jadi tanda
    // hubung atau nol, dan yang membedakannya cuma warna: abu, bukan hijau,
    // karena belum ada yang pasti untuk dinyatakan.
    final belumBerharga = order.harga == null;

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
                      style: teks.bodyMedium?.copyWith(
                        color: skema.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spasiKecil),
                  LencanaStatus(status: order.status),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${order.kodeOrder} · ${formatWaktuRelatif(order.dibuatPada)}',
                style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
              ),
              if (order.deskripsi != null) ...[
                const SizedBox(height: AppTheme.spasiKecil),
                Text(
                  order.deskripsi!,
                  style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppTheme.spasiSedang),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      belumBerharga
                          ? 'Harga menunggu penawaran'
                          : formatRupiah(order.harga),
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: belumBerharga
                            ? skema.onSurfaceVariant
                            : skema.primary,
                      ),
                    ),
                  ),
                  // Satu-satunya penanda bahwa kartu ini bisa ditekan. Tanpa itu
                  // yang membedakannya dari kartu yang cuma memberi tahu adalah
                  // percobaan, dan percobaan yang gagal membuat orang berhenti
                  // mencoba di tempat lain juga.
                  Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: skema.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
