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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E2D6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      child: Column(
        children: [
          for (final baris in hasil.rincian)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      baris.label,
                      style: const TextStyle(
                        color: Color(0xFF5A665C),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    formatRupiah(baris.nominal),
                    style: const TextStyle(
                      color: Color(0xFF1E2124),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: Color(0xFFE5EDE5), height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Biaya',
                style: TextStyle(
                  color: Color(0xFF1E2124),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formatRupiah(hasil.total),
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00AA13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
