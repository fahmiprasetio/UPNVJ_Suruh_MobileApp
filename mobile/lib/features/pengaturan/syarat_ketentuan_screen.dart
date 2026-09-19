import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Layar Syarat & Ketentuan layanan UPNVJ Suruh.
///
/// Memuat aturan main perantara jasa serabutan mahasiswa kampus UPNVJ,
/// larangan pemesanan barang berbahaya, dan tata cara pembatalan.
class SyaratKetentuanScreen extends StatelessWidget {
  const SyaratKetentuanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Syarat & Ketentuan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        children: [
          Text(
            'Syarat & Ketentuan Layanan',
            style: teks.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: skema.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Terakhir diperbarui: September 2026',
            style: teks.bodySmall?.copyWith(
              color: skema.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          _bagianPasal(
            context,
            '1. Ketentuan Umum',
            'UPNVJ Suruh merupakan platform perantara jasa serabutan mahasiswa di lingkungan Universitas Pembangunan Nasional "Veteran" Jakarta di bawah naungan Bidang Ekonomi Kreatif.\n\nPengguna platform terdiri atas Klien (pemesan jasa) dan Runner (mitra eksekutor jasa yang terdaftar dan terverifikasi).',
          ),
          _bagianPasal(
            context,
            '2. Pemesanan dan Pembayaran',
            'Klien wajib memberikan rincian alamat, nomor kontak, serta deskripsi pekerjaan yang jelas dan benar.\n\nPembayaran seluruh layanan wajib diselesaikan di muka melalui QRIS resmi yang disediakan aplikasi. Pesanan Jalur A baru disiarkan setelah pembayaran terverifikasi. Pada Jalur B, pembayaran dilakukan setelah klien menyetujui salah satu penawaran harga dari runner.',
          ),
          _bagianPasal(
            context,
            '3. Larangan dan Batasan Jasa',
            'Klien dilarang keras memesan pengantaran atau pembelian barang yang melanggar hukum dan tata tertib kampus UPNVJ, termasuk namun tidak terbatas pada: minuman beralkohol, rokok/vape ilegal, narkotika, obat-obatan terlarang, senjata tajam, serta barang berbahaya lainnya.\n\nRunner berhak membatalkan pesanan secara sepihak jika menemukan indikasi pelanggaran aturan ini.',
          ),
          _bagianPasal(
            context,
            '4. Pelaksanaan dan Bukti Selesai',
            'Runner bertanggung jawab menyelesaikan pesanan sesuai kesepakatan waktu dan alamat. Sebelum pesanan dapat ditandai selesai, runner wajib melampirkan foto bukti serah terima pekerjaan yang sah dan asli melalui aplikasi.',
          ),
          _bagianPasal(
            context,
            '5. Pembatalan dan Pengembalian Dana',
            'Pesanan yang belum dibayar dapat dibatalkan kapan saja oleh klien. Untuk pesanan yang telah dibayar, pembatalan memerlukan persetujuan admin untuk melindungi kepentingan kedua belah pihak dan memproses pengembalian dana (refund).',
          ),
        ],
      ),
    );
  }

  Widget _bagianPasal(BuildContext context, String judul, String isi) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spasiSedang),
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      decoration: BoxDecoration(
        color: skema.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
        border: Border.all(
          color: skema.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            style: teks.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: skema.onSurface,
            ),
          ),
          const SizedBox(height: AppTheme.spasiKecil),
          Text(
            isi,
            style: teks.bodyMedium?.copyWith(
              color: skema.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
