import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Layar Tentang Aplikasi UPNVJ Suruh.
///
/// Memuat identitas aplikasi, versi build, profil kemitraan Bidang Ekonomi Kreatif,
/// serta susunan founder mitra dan pengembang capstone.
class TentangAplikasiScreen extends StatelessWidget {
  const TentangAplikasiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tentang Aplikasi'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spasiSedang,
          vertical: AppTheme.spasiBesar / 2,
        ),
        children: [
          // Logo dan identitas utama
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spasiSedang),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo/lencana.png',
                    width: 96,
                    height: 96,
                  ),
                ),
                const SizedBox(height: AppTheme.spasiSedang),
                Text(
                  'UPNVJ Suruh',
                  style: teks.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: skema.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Versi 1.0.0 (Build Capstone)',
                  style: teks.bodyMedium?.copyWith(
                    color: skema.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Solusi Jasa Serabutan Mahasiswa Kampus',
                  style: teks.bodySmall?.copyWith(
                    color: skema.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spasiBesar),

          // Profil Mitra
          _kartuInformasi(
            context,
            Icons.business_outlined,
            'Profil Mitra Inisiatif',
            'UPNVJ Suruh adalah platform jasa serabutan mahasiswa di lingkungan Universitas Pembangunan Nasional "Veteran" Jakarta di bawah naungan Bidang Ekonomi Kreatif. Bertujuan memberdayakan potensi ekonomi mahasiswa sekaligus menjawab kebutuhan mendesak warga kampus secara praktis dan terpercaya.',
          ),
          const SizedBox(height: AppTheme.spasiSedang),

          // Tim Mitra & Eksekutor
          _kartuInformasi(
            context,
            Icons.groups_outlined,
            'Founder & Tim Mitra',
            'Founder:\n• Jiro Rizayanto\n\nCo-Founders & Eksekutor:\n• Adji\n• Rifqi\n• Anas\n• Diova\n• Ivan\n• Wigen',
          ),
          const SizedBox(height: AppTheme.spasiSedang),

          // Capstone Project
          _kartuInformasi(
            context,
            Icons.school_outlined,
            'Tugas Akhir / Capstone Project',
            'Aplikasi ini dikembangkan sebagai karya proyek tugas akhir (Capstone Project) mahasiswa Program Studi Informatika, Fakultas Ilmu Komputer, Universitas Pembangunan Nasional "Veteran" Jakarta.',
          ),
          const SizedBox(height: AppTheme.spasiBesar),

          Center(
            child: Text(
              '© 2026 UPNVJ Suruh. All rights reserved.',
              style: teks.bodySmall?.copyWith(
                color: skema.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spasiSedang),
        ],
      ),
    );
  }

  Widget _kartuInformasi(
    BuildContext context,
    IconData ikon,
    String judul,
    String isi,
  ) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      decoration: BoxDecoration(
        color: skema.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        border: Border.all(
          color: skema.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 20, color: skema.primary),
              const SizedBox(width: AppTheme.spasiKecil),
              Expanded(
                child: Text(
                  judul,
                  style: teks.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: skema.onSurface,
                  ),
                ),
              ),
            ],
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
