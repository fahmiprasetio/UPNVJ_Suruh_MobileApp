import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Panel alat penguji, padanan halaman simulator di sandbox Midtrans.
///
/// Sengaja dibuat mencolok dan bertuliskan apa adanya, supaya tidak pernah
/// tertukar dengan bagian aplikasi yang sungguhan. Panel ini hilang sendiri
/// begitu gateway asli dipasang, karena penyedianya mengembalikan `null`.
class PanelSimulator extends StatelessWidget {
  const PanelSimulator({super.key, required this.onBayar});

  final VoidCallback onBayar;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      decoration: BoxDecoration(
        color: skema.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        border: Border.all(color: skema.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 18, color: skema.error),
              const SizedBox(width: AppTheme.spasiKecil),
              Text(
                'ALAT PENGUJI',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: skema.error,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spasiKecil),
          Text(
            'Gateway sungguhan belum terpasang karena butuh server. Tombol ini '
            'menggantikan bank klien: menekannya membuat gateway mengabarkan '
            'bahwa uang sudah masuk.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: skema.onErrorContainer,
            ),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          OutlinedButton.icon(
            onPressed: onBayar,
            icon: const Icon(Icons.bolt_outlined),
            label: const Text('Simulasikan pembayaran masuk'),
            style: OutlinedButton.styleFrom(
              foregroundColor: skema.error,
              side: BorderSide(color: skema.error),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }
}
