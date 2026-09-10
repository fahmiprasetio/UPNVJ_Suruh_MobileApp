import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/service_catalog.dart';

/// Satu petak layanan di beranda klien, gaya pintasan super app: ikon dan
/// nama saja, tanpa penjelasan.
///
/// Sebelumnya tiap petak membawa satu baris keterangan di bawah namanya.
/// Dilepas atas permintaan pemilik produk, mencontoh referensi Gojek/Grab:
/// pintasan sebanyak ini terasa beragam justru karena tiap petak menuntut
/// dibaca, bukan sekadar dikenali dari ikon dan satu kata. Nama layanan sudah
/// cukup menjelaskan dirinya sendiri begitu ikonnya duduk di sampingnya.
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

    // Tanpa `Card`: gaya pintasan tidak punya garis rambut atau bayangan
    // sendiri, ikon dan namanya berdiri langsung di atas latar beranda, sama
    // seperti rujukannya. `InkWell` dibulatkan sendiri secukupnya supaya
    // sambutan ketukan tidak persegi mentah.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: kepekatan,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    // Dinaikkan dari 52: grid sekarang dipatok 3 kolom, jadi
                    // tiap petak lebih lebar dari sebelumnya, dan keping ikon
                    // sekecil 52 menyisakan banyak ruang kosong di kiri-kanan.
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: skema.primaryContainer,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusKontrol,
                      ),
                    ),
                    child: Icon(
                      layanan.icon,
                      size: 30,
                      color: skema.onPrimaryContainer,
                    ),
                  ),
                  // Bukan hijau atau maroon, keduanya sudah berarti sesuatu di
                  // sistem ini. Titik netral kecil di pojok cukup untuk
                  // membedakan "belum ada" dari "biasa saja" tanpa menuntut
                  // ruang teks yang sudah tidak ada di petak sekecil ini.
                  if (!tersedia)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: skema.outline,
                          border: Border.all(
                            color: skema.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.schedule,
                          size: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spasiKecil),
            Opacity(
              opacity: kepekatan,
              child: Text(
                layanan.nama,
                textAlign: TextAlign.center,
                style: teks.labelMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pintu kedua di beranda: permintaan bebas di luar katalog.
///
/// Sengaja melebar dan berbeda bentuk dari petak layanan, karena ini pintu yang
/// berbeda sifatnya: masuk lewat sini berarti harganya belum diketahui dan harus
/// lewat tawar-menawar dengan runner (Jalur B). Bedanya bentuk itu satu-satunya tempat
/// pengguna belajar bahwa ada dua jalan, jadi ia tidak boleh dilebur jadi petak
/// ketujuh di petak atas.
///
/// Ini juga satu-satunya kartu berisi warna penuh di beranda.
///
/// ## Kenapa hijau, bukan maroon
///
/// Sebelumnya bidang ini maroon, mengikuti aturan "maroon berarti tekan ini".
/// Diganti atas permintaan pemilik produk dengan alasan yang mengalahkan
/// aturan itu di tempat ini: merah dibaca orang sebagai bahaya atau
/// peringatan, sesuatu yang sebaiknya dipikir dulu sebelum ditekan. Padahal
/// memesan adalah pekerjaan utama aplikasi ini, hal yang memang harus sering
/// ditekan. Merah dipakai untuk yang perlu diwaspadai, bukan untuk pintu
/// masuk fitur utama.
///
/// Yang membedakan pintu ini dari petak di atasnya tetap utuh, karena
/// pembedanya memang bukan warna melainkan bentuk: bilah selebar layar
/// melawan petak.
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
    // Wadah hijau, dan sama di kedua tema. Peran wadah memang yang dibuat
    // Material untuk bidang selebar ini: ia sudah punya pasangan warna teksnya
    // sendiri yang terbaca di terang maupun gelap, jadi tidak perlu dua cabang
    // warna yang harus dijaga bersamaan.
    final warnaPintu = skema.primaryContainer;
    final warnaTeksPintu = skema.onPrimaryContainer;

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
