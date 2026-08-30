import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/pricing/kalkulator_tarif.dart';

/// Rincian harga Jalur A, terurai baris per baris lalu totalnya.
class RingkasanHarga extends StatelessWidget {
  const RingkasanHarga({super.key, required this.hasil});

  final HasilTarif hasil;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Column(
          children: [
            for (final baris in hasil.rincian)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        baris.label,
                        style: teks.bodyMedium?.copyWith(
                          color: skema.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(formatRupiah(baris.nominal), style: teks.bodyMedium),
                  ],
                ),
              ),
            Divider(color: skema.outlineVariant, height: AppTheme.spasiSedang),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: teks.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                // Seukuran harga di daftar order dan di detail, bukan seukuran
                // baris rinciannya. Ini satu-satunya angka di kartu ini yang
                // benar-benar akan dibayar orang; sisanya cuma menerangkan dari
                // mana angka itu datang.
                Text(
                  formatRupiah(hasil.total),
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ).copyWith(color: skema.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
