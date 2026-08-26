import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/service_catalog.dart';

/// Satu petak layanan di beranda klien.
class KartuLayanan extends StatelessWidget {
  const KartuLayanan({super.key, required this.layanan, required this.onTap});

  final ServiceInfo layanan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spasiSedang),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: skema.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  layanan.icon,
                  size: 22,
                  color: skema.onPrimaryContainer,
                ),
              ),
              const Spacer(),
              Text(
                layanan.nama,
                style: teks.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                layanan.deskripsi,
                style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pintu kedua di beranda: permintaan bebas di luar katalog.
///
/// Sengaja dibuat melebar dan berbeda bentuk dari petak layanan, karena ini
/// pintu yang berbeda sifatnya, masuk lewat sini berarti harga belum
/// diketahui dan harus lewat penawaran admin (Jalur B).
class KartuPermintaanLain extends StatelessWidget {
  const KartuPermintaanLain({
    super.key,
    required this.layanan,
    required this.onTap,
  });

  final ServiceInfo layanan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: skema.secondaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spasiSedang),
          child: Row(
            children: [
              Icon(layanan.icon, size: 28, color: skema.onSecondaryContainer),
              const SizedBox(width: AppTheme.spasiSedang),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layanan.nama,
                      style: teks.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: skema.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      layanan.deskripsi,
                      style: teks.bodySmall?.copyWith(
                        color: skema.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: skema.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
