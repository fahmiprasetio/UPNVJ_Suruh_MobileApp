import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/order.dart';

/// Bukti pekerjaan yang ditinggalkan runner, dilihat dari sisi klien.
///
/// Sebelum ini alur buktinya putus: runner wajib memotret, tapi tidak ada
/// seorang pun yang bisa melihat hasilnya. Kewajiban yang hasilnya tidak
/// pernah dibaca cepat berubah jadi formalitas.
class KartuBuktiPekerjaan extends StatelessWidget {
  const KartuBuktiPekerjaan({super.key, required this.order});

  final Order order;

  /// Foto hanya bisa digambar kalau tautannya sungguhan.
  ///
  /// Selama penyimpanan foto belum diputuskan (rencana capstone bagian 14.4),
  /// yang tersimpan adalah tautan tiruan berskema `fake://`. Memaksa
  /// menggambarnya cuma menghasilkan kotak gagal muat tanpa keterangan,
  /// lebih jujur mengatakan kenapa.
  static bool bisaDigambar(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final fotoUrl = order.fotoBuktiUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order.selesaiPada != null)
              Text(
                'Diselesaikan ${formatTanggalJam(order.selesaiPada!)}',
                style: teks.bodySmall?.copyWith(
                  color: skema.onSurfaceVariant,
                ),
              ),
            if (fotoUrl != null) ...[
              const SizedBox(height: AppTheme.spasiKecil),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: bisaDigambar(fotoUrl)
                    ? Image.network(
                        fotoUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, galat, jejak) =>
                            const _FotoBelumBisaDilihat(
                              pesan: 'Foto bukti gagal dimuat.',
                            ),
                      )
                    : const _FotoBelumBisaDilihat(
                        pesan:
                            'Foto bukti sudah dikirim runner, tapi belum bisa '
                            'ditampilkan, penyimpanan foto belum terpasang.',
                      ),
              ),
            ],
            if (order.catatanSerahTerima != null) ...[
              const SizedBox(height: AppTheme.spasiSedang),
              Text(
                'Catatan runner',
                style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(order.catatanSerahTerima!, style: teks.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _FotoBelumBisaDilihat extends StatelessWidget {
  const _FotoBelumBisaDilihat({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Container(
      height: 140,
      width: double.infinity,
      color: skema.surfaceContainerHighest,
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: skema.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.spasiKecil),
          Text(
            pesan,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
