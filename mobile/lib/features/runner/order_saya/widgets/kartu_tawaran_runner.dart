import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/enums.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/models/order_offer.dart';
import '../../../../domain/service_catalog.dart';

/// Satu tawaran yang sudah dikirim runner dan belum berakhir.
///
/// Sengaja bukan [KartuOrderRunner] dengan tombol berbeda: yang ditampilkan di sini
/// bukan pekerjaan melainkan tawaran, dan angka terbesarnya harga yang RUNNER
/// tawarkan, bukan harga order. Order Jalur B yang masih menerima tawaran memang
/// belum punya harga sama sekali, jadi kartu yang menyorot harga order akan menyorot
/// tempat kosong.
class KartuTawaranRunner extends StatelessWidget {
  const KartuTawaranRunner({
    super.key,
    required this.order,
    required this.penawaran,
    this.onTarik,
    this.onChat,
  });

  final Order order;
  final OrderOffer penawaran;

  /// Hanya ada selama tawarannya masih bisa ditarik. Yang sudah disetujui tidak:
  /// harga ordernya sudah ditetapkan dari tawaran ini dan klien mungkin sedang
  /// membayarnya.
  final VoidCallback? onTarik;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: Text(
                    serviceInfoOf(order.serviceType).nama,
                    style: teks.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  order.kodeOrder,
                  style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
                ),
              ],
            ),
            if (order.deskripsi != null) ...[
              const SizedBox(height: AppTheme.spasiKecil),
              Text(order.deskripsi!, style: teks.bodyMedium),
            ],
            const SizedBox(height: AppTheme.spasiSedang),
            Text(
              'Kamu menawar',
              style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
            ),
            Text(
              formatRupiah(penawaran.harga),
              style: TextStyle(
                fontSize: 20,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: skema.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spasiKecil),
            // Statusnya ditulis, bukan disimpulkan dari ada tidaknya tombol. Runner yang
            // tawarannya diminta dihitung ulang perlu tahu itu, dan itu satu-satunya
            // petunjuk bahwa ada pesan menunggu di chatnya.
            Row(
              children: [
                Icon(_ikon, size: 16, color: skema.onSurfaceVariant),
                const SizedBox(width: AppTheme.spasiKecil),
                Expanded(
                  child: Text(
                    _keterangan,
                    style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (onTarik != null || onChat != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (onChat != null)
                    TextButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.forum_outlined, size: 18),
                      label: Text(
                        order.jumlahPesanBelumDibaca == 0
                            ? 'Chat Klien'
                            : 'Chat Klien (${order.jumlahPesanBelumDibaca})',
                      ),
                      style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                    ),
                  const Spacer(),
                  // Di ujung seberang dan tanpa ikon, alasannya sama dengan "Lepas
                  // order": jalan keluar yang memang harus ada, bukan tindakan yang
                  // pantas ditawarkan sejajar dengan membuka percakapan.
                  if (onTarik != null)
                    TextButton(
                      onPressed: onTarik,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: skema.onSurfaceVariant,
                      ),
                      child: const Text('Tarik tawaran'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _ikon => switch (penawaran.status) {
    OfferStatus.disetujui => Icons.check_circle_outline,
    OfferStatus.dinegoUlang => Icons.reply_outlined,
    _ => Icons.hourglass_top_outlined,
  };

  String get _keterangan => switch (penawaran.status) {
    OfferStatus.disetujui =>
      'Tawaranmu dipilih. Ordermu mulai begitu klien melunasi.',
    OfferStatus.dinegoUlang =>
      'Klien minta dihitung ulang. Alasannya ada di chat; tarik tawaran ini '
          'lalu kirim angka baru.',
    _ => 'Menunggu jawaban klien.',
  };
}
