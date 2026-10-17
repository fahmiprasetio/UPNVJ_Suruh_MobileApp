import 'package:flutter/material.dart';

import '../../../../core/api/galat_api.dart';
import '../../../../core/theme/app_theme.dart';

/// Panel alat penguji, padanan halaman simulator di sandbox Midtrans.
///
/// Sengaja dibuat mencolok dan bertuliskan apa adanya, supaya tidak pernah
/// tertukar dengan bagian aplikasi yang sungguhan. Panel ini hanya tersedia di
/// build debug; build demo rilis dan produksi tidak pernah menampilkannya.
class PanelSimulator extends StatefulWidget {
  const PanelSimulator({super.key, required this.onBayar});

  final Future<void> Function() onBayar;

  @override
  State<PanelSimulator> createState() => _PanelSimulatorState();
}

class _PanelSimulatorState extends State<PanelSimulator> {
  bool _sedangMemproses = false;

  Future<void> _bayar() async {
    if (_sedangMemproses) return;
    setState(() => _sedangMemproses = true);

    try {
      await widget.onBayar();
    } catch (galat) {
      if (!mounted) return;
      final pesan = galat is GalatApi
          ? galat.pesan
          : 'Simulasi pembayaran gagal. Coba lagi, ya.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(pesan)));
    } finally {
      if (mounted) setState(() => _sedangMemproses = false);
    }
  }

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
            'Khusus Development. Tombol ini menggantikan bank klien: '
            'menekannya membuat server mengabarkan bahwa pembayaran simulasi '
            'sudah masuk.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: skema.onErrorContainer),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          OutlinedButton.icon(
            onPressed: _sedangMemproses ? null : _bayar,
            icon: _sedangMemproses
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bolt_outlined),
            label: Text(
              _sedangMemproses
                  ? 'Memproses pembayaran...'
                  : 'Simulasikan pembayaran masuk',
            ),
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
