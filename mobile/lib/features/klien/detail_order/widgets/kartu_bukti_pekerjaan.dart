import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/enums.dart';
import '../../../../domain/models/order.dart';
import '../../../../core/providers/repository_providers.dart';

/// Bukti pekerjaan yang ditinggalkan runner, dilihat dari sisi klien.
///
/// Sebelum ini alur buktinya putus: runner wajib memotret, tapi tidak ada
/// seorang pun yang bisa melihat hasilnya. Kewajiban yang hasilnya tidak
/// pernah dibaca cepat berubah jadi formalitas.
class KartuBuktiPekerjaan extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final fotoUrl = order.fotoBuktiUrl;
    final isMakanan = order.serviceType == ServiceType.jastipMakanan;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF00AA13),
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMakanan
                          ? 'Bukti Pengantaran / Struk Makanan'
                          : 'Bukti Serah Terima Tugas',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (order.selesaiPada != null)
                      Text(
                        'Selesai pada ${formatTanggalJam(order.selesaiPada!)} WIB',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (fotoUrl != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: bisaDigambar(fotoUrl)
                  ? Image.network(
                      fotoUrl,
                      // Foto bukti dijaga token sejak ia berhenti dilayani sebagai
                      // berkas statis. Tanpa header ini permintaannya dijawab 401.
                      headers: ref.watch(klienApiProvider).headerOtorisasi,
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
          if (order.catatanSerahTerima != null &&
              order.catatanSerahTerima!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Catatan Runner:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    order.catatanSerahTerima!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1F2937),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
