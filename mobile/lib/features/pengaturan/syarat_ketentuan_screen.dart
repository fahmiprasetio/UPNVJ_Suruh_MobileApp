import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Layar Syarat & Ketentuan layanan UPNVJ Suruh.
///
/// Memuat aturan main perantara jasa serabutan mahasiswa kampus UPNVJ,
/// larangan pemesanan barang berbahaya, dan tata cara pembatalan.
///
/// Isinya sama dengan halaman publik `/syarat-ketentuan` yang dilayani API
/// (`HalamanPublik.Syarat`): judul pasal, urutan, dan kalimatnya. Kalau salah satunya diubah,
/// ubah keduanya. Tes di kedua sisi menjaga daftar judul pasalnya ([judulPasal]).
class SyaratKetentuanScreen extends StatelessWidget {
  const SyaratKetentuanScreen({super.key});

  /// Ikut diubah bersama isi di bawah dan di halaman publik.
  static const String diperbaruiPada = '20 Oktober 2026';

  /// Judul pasal, urutannya sama dengan `<h2>` di halaman publik. Dipakai tes.
  static List<String> get judulPasal => [for (final p in _pasal) p.$1];

  static const List<(String, String)> _pasal = [
    (
      '1. Ketentuan umum',
      'UPNVJ Suruh adalah platform perantara jasa serabutan mahasiswa di lingkungan '
          'Universitas Pembangunan Nasional "Veteran" Jakarta, di bawah naungan Bidang '
          'Ekonomi Kreatif. Pengguna terdiri atas Klien (pemesan jasa) dan Runner (mitra '
          'pelaksana yang terdaftar dan terverifikasi).',
    ),
    (
      '2. Pemesanan dan pembayaran',
      'Klien wajib memberikan alamat, nomor kontak, dan deskripsi pekerjaan yang jelas dan '
          'benar. Pembayaran dilakukan melalui halaman Midtrans. Pesanan Jalur A baru '
          'disiarkan ke runner setelah pembayaran terverifikasi. Pada Jalur B, pembayaran '
          'dilakukan setelah klien menyetujui salah satu penawaran harga dari runner.',
    ),
    (
      '3. Larangan dan batasan jasa',
      'Klien dilarang memesan pengantaran atau pembelian barang yang melanggar hukum dan '
          'tata tertib kampus, termasuk minuman beralkohol, rokok atau vape ilegal, '
          'narkotika, obat-obatan terlarang, senjata tajam, dan barang berbahaya lainnya. '
          'Runner berhak membatalkan pesanan bila menemukan indikasi pelanggaran ini.',
    ),
    (
      '4. Pelaksanaan dan bukti selesai',
      'Runner menyelesaikan pesanan sesuai kesepakatan waktu dan alamat. Pesanan baru dapat '
          'ditandai selesai setelah runner melampirkan foto bukti serah terima beserta '
          'catatannya.',
    ),
    (
      '5. Pembatalan dan pengembalian dana',
      'Pesanan yang belum dibayar dapat dibatalkan klien kapan saja. Untuk pesanan yang '
          'sudah dibayar, pembatalan dilakukan lewat admin, yang sekaligus mencatat '
          'pengembalian dana. Dana dikembalikan melalui penyedia pembayaran sesuai '
          'ketentuannya.',
    ),
    (
      '6. Akun',
      'Satu nomor HP untuk satu akun. Akun dapat ditangguhkan bila ada penyalahgunaan, dan '
          'pemiliknya dapat menghapus akunnya sendiri sesuai Kebijakan Privasi.',
    ),
    (
      '7. Kontak',
      'Pertanyaan tentang data dan privasi dapat disampaikan lewat menu Pusat Bantuan di '
          'aplikasi.',
    ),
  ];

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
            'Terakhir diperbarui: $diperbaruiPada',
            style: teks.bodySmall?.copyWith(
              color: skema.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          for (final (judul, isi) in _pasal) _bagianPasal(context, judul, isi),
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
