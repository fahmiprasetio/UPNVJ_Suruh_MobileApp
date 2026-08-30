import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/service_catalog.dart';

/// Satu petak layanan di beranda klien.
///
/// Ikonnya duduk di keping hijau di atas, nama dan keterangannya dipaku ke
/// bawah oleh [Spacer]. Pemakuan itu yang membuat enam petak terlihat rata
/// walaupun namanya membungkus ke jumlah baris yang berbeda-beda.
class KartuLayanan extends StatelessWidget {
  const KartuLayanan({
    super.key,
    required this.layanan,
    required this.onTap,
    this.tersedia = true,
  });

  final ServiceInfo layanan;
  final VoidCallback onTap;

  /// Salah kalau layarnya belum dibuat.
  ///
  /// Petak yang menjanjikan sesuatu lalu menjawab "menyusul" setelah ditekan
  /// membuat pengguna menanggung penemuan yang seharusnya ditanggung layar.
  /// Ditandai di muka, ia cuma satu hal yang belum ada; ditandai setelah
  /// ditekan, ia terasa seperti aplikasi yang rusak.
  final bool tersedia;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    // Diredupkan, bukan dimatikan. Petaknya tetap bisa ditekan supaya
    // keterangannya bisa dibaca; yang berubah cuma seberapa keras ia memanggil.
    final kepekatan = tersedia ? 1.0 : 0.55;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spasiSedang),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Opacity(
                    opacity: kepekatan,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: skema.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusKontrol,
                        ),
                      ),
                      child: Icon(
                        layanan.icon,
                        size: 22,
                        color: skema.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!tersedia) const _LencanaSegera(),
                ],
              ),
              const Spacer(),
              Opacity(
                opacity: kepekatan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layanan.nama,
                      style: teks.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      layanan.deskripsi,
                      style: teks.bodySmall?.copyWith(
                        color: skema.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Penanda layanan yang layarnya belum dibuat.
///
/// Bentuknya pil penuh, sama seperti lencana status order, karena yang
/// disampaikannya juga sebuah keadaan: mata mencari pil untuk tahu keadaan
/// sesuatu tanpa harus membacanya.
class _LencanaSegera extends StatelessWidget {
  const _LencanaSegera();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: skema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusPil),
      ),
      child: Text(
        'Segera',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: skema.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Pintu kedua di beranda: permintaan bebas di luar katalog.
///
/// Sengaja melebar dan berbeda bentuk dari petak layanan, karena ini pintu yang
/// berbeda sifatnya: masuk lewat sini berarti harganya belum diketahui dan harus
/// lewat penawaran admin (Jalur B). Bedanya bentuk itu satu-satunya tempat
/// pengguna belajar bahwa ada dua jalan, jadi ia tidak boleh dilebur jadi petak
/// ketujuh di petak atas.
///
/// Ini juga satu-satunya kartu berisi warna penuh di beranda. Warnanya maroon,
/// warna yang di sistem ini selalu berarti "tekan ini".
class KartuPermintaanLain extends StatelessWidget {
  const KartuPermintaanLain({
    super.key,
    required this.layanan,
    required this.onTap,
  });

  final ServiceInfo layanan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    final gelap = Theme.of(context).brightness == Brightness.dark;

    // Terang memakai maroon penuh, gelap memakai wadahnya.
    //
    // Bukan demi variasi. Di Material, peran berkekuatan penuh pada tema gelap
    // adalah warna muda yang dibuat untuk teks, bukan untuk isian: maroon muda
    // selebar bilah ini akan menyala merah jambu di tengah malam. Yang dicari
    // sama di kedua tema, yaitu satu bidang maroon yang meyakinkan, dan peran
    // yang menghasilkannya kebetulan berbeda nama.
    //
    // Sebelumnya keduanya memakai wadah, dan di tema terang hasilnya merah muda
    // pucat: bukan pintu yang mengundang, melainkan bidang yang terbaca seperti
    // peringatan yang lupa diselesaikan.
    final warnaPintu = gelap ? skema.secondaryContainer : skema.secondary;
    final warnaTeksPintu = gelap
        ? skema.onSecondaryContainer
        : skema.onSecondary;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: warnaPintu,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        // Tanpa garis rambut abu: kartu ini sudah punya isian sendiri yang
        // memisahkannya dari latar, dan garis netral di atas bidang berwarna
        // terbaca sebagai sisa yang lupa dibuang.
        side: BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spasiSedang),
          child: Row(
            children: [
              Icon(layanan.icon, size: 28, color: warnaTeksPintu),
              const SizedBox(width: AppTheme.spasiSedang),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layanan.nama,
                      style: teks.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: warnaTeksPintu,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      layanan.deskripsi,
                      style: teks.bodySmall?.copyWith(
                        color: warnaTeksPintu,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spasiKecil),
              Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: warnaTeksPintu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
