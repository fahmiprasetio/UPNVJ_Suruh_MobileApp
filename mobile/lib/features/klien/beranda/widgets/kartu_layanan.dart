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

  /// Sisi dasar ilustrasi sebelum dikali [ServiceInfo.skalaIkon]. Kotak
  /// kartunya sendiri (90) tidak ikut membesar biar kartunya tetap seragam;
  /// yang membesar cuma ilustrasinya, menjulur lebih jauh keluar kotak.
  static const double _sisiDasarIlustrasi = 100;

  /// Tinggi area ikon, TETAP sama untuk semua petak, dipatok dari ilustrasi
  /// terbesar di katalog (skala 1.1 x 100 = 110, Jastip Makanan & Bantu
  /// Pindah Kos di `service_catalog.dart`).
  ///
  /// Kalau ini ikut mengecil untuk petak yang skalanya 1 (tidak dibesarkan),
  /// namanya jadi naik lebih tinggi dibanding tetangganya di baris yang sama
  /// -- rapi sendiri-sendiri tapi barisnya jadi bergerigi. Areanya tetap sama
  /// rata, yang beda cuma seberapa jauh ilustrasinya menjulur turun di
  /// dalamnya.
  ///
  /// Jangan diturunkan lagi di bawah 110: `Stack` di atas pakai
  /// `clipBehavior: Clip.none`, jadi bagian ilustrasi yang menjulur lewat
  /// batas ini tidak dipotong -- ia akan tumpang tindih dengan nama layanan
  /// di bawahnya.
  static const double _tinggiArea = 110;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;

    // Diredupkan, bukan dimatikan. Petaknya tetap bisa ditekan supaya
    // keterangannya bisa dibaca; yang berubah cuma seberapa keras ia memanggil.
    final kepekatan = tersedia ? 1.0 : 0.55;
    final sisiIlustrasi = _sisiDasarIlustrasi * layanan.skalaIkon;

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
              // Areanya sengaja lebih tinggi dari kotaknya sendiri (kotaknya
              // cuma 90): ilustrasinya digambar lebih besar dari kotak lalu
              // ditumpuk dari atas, sehingga kaki/bagian bawahnya menjulur
              // keluar kotak, mengikuti rancangan Figma. Tingginya TETAP
              // (`_tinggiArea`) untuk semua petak, bukan ikut ukuran ilustrasi
              // masing-masing, supaya nama layanan tetap serata di baris yang
              // sama biarpun sebagian ilustrasinya dibesarkan.
              child: SizedBox(
                height: _tinggiArea,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: skema.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusKontrol,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(3, 4),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      // Nempel ke bawah area (`bottom: 0`), bukan ke atas:
                      // ilustrasi yang skalanya 1 (100) lebih pendek dari
                      // `_tinggiArea` (110), jadi kalau ditempel ke atas
                      // sisa 10px kosong itu jatuh di BAWAH ilustrasi --
                      // ikonnya kelihatan menggantung tinggi, jauh dari nama.
                      // Ditempel ke bawah, sisa kosongnya pindah ke ATAS
                      // ilustrasi (tidak kelihatan, cuma jarak ke kartu di
                      // atasnya), dan ikonnya duduk lebih rendah, dekat nama.
                      // Tinggi dipatok eksplisit: tanpa ini `Positioned`
                      // memberi tinggi TAK TERBATAS ke `OverflowBox` (cuma
                      // satu sisi vertikal yang dipatok), dan `OverflowBox`
                      // -- beda dari `Align` -- menolak diberi tinggi tak
                      // terbatas untuk dirinya sendiri.
                      height: sisiIlustrasi,
                      // `left`/`right` di atas mengunci lebar slot ini
                      // selebar kotak 90 -- pas untuk petak yang ilustrasinya
                      // tidak dibesarkan, tapi untuk yang dibesarkan (sampai
                      // 264) lebar segitu malah MEMOTONG lebar gambarnya jadi
                      // 90 juga sebelum sempat membesar, dan hasilnya gambar
                      // tercekik lalu mengambang aneh di tengah area. `Align`
                      // ikut terkena batas lebar yang sama, jadi diganti
                      // `OverflowBox`: dia sengaja mengabaikan batas dari
                      // induknya untuk anaknya sendiri, jadi ilustrasi yang
                      // lebih lebar dari kotak tetap dapat lebar penuh
                      // (`sisiIlustrasi`), bukan ikut disempitkan.
                      child: OverflowBox(
                        minWidth: 0,
                        maxWidth: sisiIlustrasi,
                        minHeight: 0,
                        maxHeight: sisiIlustrasi,
                        alignment: Alignment.topCenter,
                        child: layanan.gambarIkon != null
                            ? Transform(
                                alignment: Alignment.center,
                                // Seluruh ilustrasi digambar menghadap kiri;
                                // dicerminkan di sini supaya semuanya
                                // menghadap kanan serempak, tanpa perlu
                                // menggambar ulang asetnya.
                                transform: Matrix4.identity()
                                  ..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
                                child: Image.asset(
                                  layanan.gambarIkon!,
                                  width: sisiIlustrasi,
                                  height: sisiIlustrasi,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : SizedBox(
                                height: 90,
                                child: Icon(
                                  layanan.icon,
                                  size: 36,
                                  color: skema.onPrimaryContainer,
                                ),
                              ),
                      ),
                    ),
                    // Bukan hijau atau maroon, keduanya sudah berarti sesuatu
                    // di sistem ini. Titik netral kecil di pojok cukup untuk
                    // membedakan "belum ada" dari "biasa saja" tanpa menuntut
                    // ruang teks yang sudah tidak ada di petak sekecil ini.
                    // Tetap relatif ke kotak 90, bukan ke area ikonnya.
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
                            border: Border.all(color: skema.surface, width: 2),
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
            ),
            // Lebih rapat dari `spasiKecil` biasa dengan sengaja: ilustrasinya
            // sendiri sudah menjulur sampai dekat batas bawah areanya, jarak
            // sebesar itu di sini malah menjauhkan namanya dari kartunya.
            const SizedBox(height: 0.5),
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
                      style: teks.bodySmall?.copyWith(color: warnaTeksPintu),
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
