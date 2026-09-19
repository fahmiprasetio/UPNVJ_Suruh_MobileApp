import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Layar Kebijakan Privasi UPNVJ Suruh.
///
/// Menjelaskan perlindungan data nomor HP mahasiswa, pembatasan akses alamat kos,
/// dan kebijakan penghapusan otomatis metadata lokasi foto (EXIF).
class KebijakanPrivasiScreen extends StatelessWidget {
  const KebijakanPrivasiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kebijakan Privasi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        children: [
          Text(
            'Kebijakan Privasi',
            style: teks.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: skema.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Komitmen keamanan dan privasi data mahasiswa UPNVJ',
            style: teks.bodySmall?.copyWith(
              color: skema.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          _butirPrivasi(
            context,
            Icons.phone_android_rounded,
            'Penggunaan Nomor Telepon',
            'Nomor telepon Anda digunakan untuk autentikasi kode OTP, verifikasi akun, dan koordinasi langsung antara klien dan runner selama pesanan aktif. Kami tidak pernah membagikan nomor Anda kepada pihak ketiga di luar keperluan transaksi layanan.',
          ),
          _butirPrivasi(
            context,
            Icons.location_on_outlined,
            'Privasi Lokasi dan Alamat Kos',
            'Alamat penjemputan atau pengantaran hanya dapat diakses oleh runner yang telah resmi menerima pesanan Anda. Runner yang tawarannya ditolak atau penugasan yang telah selesai tidak memiliki akses lagi ke rincian alamat Anda.',
          ),
          _butirPrivasi(
            context,
            Icons.camera_enhance_outlined,
            'Pembersihan Metadata Foto (EXIF)',
            'Foto serah terima pekerjaan yang diunggah oleh runner diproses di sisi server untuk membuang seluruh metadata EXIF (termasuk titik koordinat GPS kamera perangkat) sebelum disimpan. Langkah ini memastikan privasi lokasi tempat tinggal mahasiswa tetap terjaga.',
          ),
          _butirPrivasi(
            context,
            Icons.shield_outlined,
            'Keamanan Autentikasi dan Kata Sandi',
            'Kata sandi Anda (jika diaktifkan) disimpan menggunakan algoritma hashing PBKDF2 dengan salt acak yang aman dan tidak dapat dibaca oleh tim pengembang sekalipun. Kode OTP diverifikasi dalam waktu tetap (constant-time) untuk mencegah kebocoran informasi.',
          ),
          _butirPrivasi(
            context,
            Icons.manage_accounts_outlined,
            'Hak Pembaruan Data Pengguna',
            'Anda dapat memperbarui nama profil, mengubah nomor telepon dengan verifikasi OTP, atau menyetel ulang kata sandi kapan saja secara mandiri melalui menu Pengaturan dan Profil.',
          ),
        ],
      ),
    );
  }

  Widget _butirPrivasi(
    BuildContext context,
    IconData ikon,
    String judul,
    String deskripsi,
  ) {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: skema.primaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
            ),
            child: Icon(
              ikon,
              size: 20,
              color: skema.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppTheme.spasiSedang),
          Expanded(
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
                const SizedBox(height: 4),
                Text(
                  deskripsi,
                  style: teks.bodyMedium?.copyWith(
                    color: skema.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
