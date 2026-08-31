import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Layar tanpa isi: kosong, gagal dimuat, atau belum pernah dipakai.
///
/// Selalu menawarkan satu jalan keluar kalau ada. Layar yang cuma menyatakan
/// keadaan meninggalkan pengguna di jalan buntu, dan jalan buntu di tab yang
/// baru pertama kali dibuka adalah kesan pertama yang tidak perlu.
///
/// ## Kenapa satu berkas, bukan satu salinan per layar
///
/// Sebelumnya ada tiga: satu di riwayat klien yang sudah ditata, dan dua di
/// permukaan runner yang masih memakai bentuk lama, ikon telanjang 44 piksel
/// tanpa cakram di belakangnya dan tanpa tombol jalan keluar. Ketiganya
/// berdampingan di aplikasi yang sama dan bedanya terlihat, tapi tidak ada satu
/// pun layar yang memperlihatkan keduanya sekaligus, jadi yang terbaca bukan
/// "dua gaya" melainkan "layar runner belum jadi".
///
/// Layar kosong justru bagian yang paling sering dilihat pengguna baru, karena
/// pengguna baru belum punya apa-apa. Menyamakannya bukan kerapian, melainkan
/// menyamakan kesan pertama.
class PesanKosong extends StatelessWidget {
  const PesanKosong({
    super.key,
    required this.ikon,
    required this.judul,
    required this.keterangan,
    this.labelAksi,
    this.onAksi,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;

  /// Label tombol jalan keluar. Tombolnya hanya muncul kalau label dan
  /// [onAksi] sama-sama ada; keadaan yang memang buntu tidak dipaksa
  /// menumbuhkan tombol yang tidak menuju ke mana-mana.
  final String? labelAksi;
  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final aksi = onAksi;
    final label = labelAksi;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiBesar),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spasiSedang),
              decoration: BoxDecoration(
                color: skema.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(ikon, size: 32, color: skema.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            Text(
              judul,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: skema.onSurfaceVariant),
            ),
            if (aksi != null && label != null) ...[
              const SizedBox(height: AppTheme.spasiBesar),
              FilledButton(
                onPressed: aksi,
                // Tidak selebar layar. Tombol di tengah layar kosong yang
                // membentang penuh terbaca sebagai formulir yang belum selesai;
                // yang ini sebuah tawaran, bukan langkah wajib.
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spasiBesar,
                  ),
                ),
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
