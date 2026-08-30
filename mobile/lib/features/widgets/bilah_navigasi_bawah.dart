import 'package:flutter/material.dart';

/// Bilah navigasi bawah, dipakai kedua permukaan.
///
/// Ada sebagai satu widget, bukan disalin ke cangkang klien dan cangkang runner,
/// karena dua bilah navigasi yang berbeda tipis di satu aplikasi adalah hal yang
/// dirasakan pengguna sebagai kegugupan tanpa pernah bisa ia tunjuk. Akun yang
/// memegang dua peran berpindah permukaan lewat tombol ganti mode, dan ia
/// melihat keduanya dalam hitungan detik.
///
/// Yang ditambahkan di atas [NavigationBar] bawaan cuma satu: garis rambut di
/// tepi atasnya. Tanpa itu, di tema terang bilahnya cuma satu tingkat lebih
/// gelap dari latar halaman, dan batas antara "isi yang menggulung" dan "kemudi
/// yang diam" jadi soal menebak. Garis itu yang membuatnya terbaca sebagai
/// kemudi, bukan sebagai baris terakhir daftar.
class BilahNavigasiBawah extends StatelessWidget {
  const BilahNavigasiBawah({
    super.key,
    required this.terpilih,
    required this.onPilih,
    required this.tujuan,
  });

  final int terpilih;
  final ValueChanged<int> onPilih;
  final List<NavigationDestination> tujuan;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: skema.surfaceContainer,
        border: Border(top: BorderSide(color: skema.outlineVariant)),
      ),
      child: NavigationBar(
        // Warnanya sudah dipegang wadah di atas, supaya garis rambutnya tidak
        // tertimpa isian bilahnya sendiri.
        backgroundColor: Colors.transparent,
        selectedIndex: terpilih,
        onDestinationSelected: onPilih,
        destinations: tujuan,
      ),
    );
  }
}
