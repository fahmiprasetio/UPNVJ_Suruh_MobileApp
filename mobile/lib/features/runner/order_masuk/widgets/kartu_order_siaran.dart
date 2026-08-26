import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/service_catalog.dart';

/// Satu order yang sedang disiarkan, dilihat dari sisi runner.
///
/// Isinya berbeda dari kartu order milik klien: runner butuh tahu apakah
/// pekerjaan ini layak diambil sekarang — jenis layanan, ke mana, dan berapa
/// nilainya — bukan sejauh mana ordernya sudah berjalan.
class KartuOrderSiaran extends StatelessWidget {
  const KartuOrderSiaran({
    super.key,
    required this.order,
    required this.onTerima,
    this.sedangDiproses = false,
  });

  final Order order;
  final VoidCallback onTerima;

  /// Tombol dikunci selama permintaan TERIMA masih di jalan, supaya satu
  /// ketukan tidak terkirim dua kali.
  final bool sedangDiproses;

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
                  formatWaktuRelatif(order.dibuatPada),
                  style: teks.bodySmall?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spasiKecil),
            Text(
              '${order.kodeOrder} · ${order.namaKlien}',
              style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
            ),
            if (order.deskripsi != null) ...[
              const SizedBox(height: AppTheme.spasiKecil),
              Text(order.deskripsi!, style: teks.bodyMedium),
            ],
            const SizedBox(height: AppTheme.spasiSedang),
            if (order.alamatJemput != null)
              _BarisAlamat(
                ikon: Icons.my_location_outlined,
                label: 'Jemput',
                alamat: order.alamatJemput!,
              ),
            if (order.alamatTujuan != null)
              _BarisAlamat(
                ikon: Icons.place_outlined,
                label: 'Tujuan',
                alamat: order.alamatTujuan!,
              ),
            if (order.jumlahRunnerDibutuhkan > 1) ...[
              const SizedBox(height: AppTheme.spasiKecil),
              _LencanaKuota(order: order),
            ],
            const SizedBox(height: AppTheme.spasiSedang),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nilai order',
                        style: teks.bodySmall?.copyWith(
                          color: skema.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        formatRupiah(order.harga),
                        style: teks.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: skema.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sengaja bukan "pendapatanmu": bagi hasil runner belum
                // diputuskan mitra (rencana capstone bagian 14.7d). Menuliskan
                // angka yang belum disepakati akan lebih menyesatkan daripada
                // tidak menuliskannya.
                SizedBox(
                  width: 148,
                  child: FilledButton(
                    onPressed: sedangDiproses ? null : onTerima,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: sedangDiproses
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('TERIMA'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarisAlamat extends StatelessWidget {
  const _BarisAlamat({
    required this.ikon,
    required this.label,
    required this.alamat,
  });

  final IconData ikon;
  final String label;
  final String alamat;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 16, color: skema.onSurfaceVariant),
          const SizedBox(width: AppTheme.spasiKecil),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: teks.bodySmall?.copyWith(color: skema.onSurface),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(color: skema.onSurfaceVariant),
                  ),
                  TextSpan(text: alamat),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Penanda order yang butuh lebih dari satu runner (bagian 5).
class _LencanaKuota extends StatelessWidget {
  const _LencanaKuota({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: skema.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Butuh ${order.jumlahRunnerDibutuhkan} orang · '
        '${order.runnerIds.length} sudah gabung',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: skema.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
