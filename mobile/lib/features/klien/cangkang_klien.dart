import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/order.dart';
import '../../providers/order_providers.dart';
import '../profil/profil_screen.dart';
import '../widgets/bilah_navigasi_bawah.dart';
import 'beranda/beranda_klien_screen.dart';

/// Permukaan klien: dua tempat yang dipakai bergantian.
///
/// Beranda untuk memesan, Profil untuk urusan akun. Riwayat order pernah punya
/// tab sendiri di sini dan sekarang tidak lagi, atas permintaan pemilik produk:
/// pintunya sudah ada di Profil, dan dua pintu ke tempat yang sama membuat
/// bilah navigasi menjanjikan dua hal berbeda yang ternyata satu.
///
/// Dipasang di [IndexedStack] supaya berpindah tab tidak membuang keadaan layar.
class CangkangKlien extends ConsumerStatefulWidget {
  const CangkangKlien({super.key});

  @override
  ConsumerState<CangkangKlien> createState() => _CangkangKlienState();
}

class _CangkangKlienState extends ConsumerState<CangkangKlien> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderKlienProvider).value?.isi ?? const <Order>[];

    // Order yang masih berjalan tidak boleh cuma diingat pemesannya sendiri.
    // Yang paling sering terlupakan justru yang paling mendesak: order yang
    // menunggu dibayar berhenti di situ sampai ada yang membukanya lagi. Sejak
    // tab riwayat dilepas, angka ini menumpang di Profil, satu-satunya tempat
    // yang tersisa di bilah ini yang memuat jalan ke riwayatnya.
    final jumlahAktif = order.where((o) => o.status.isAktif).length;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [BerandaKlienScreen(), ProfilScreen()],
      ),
      bottomNavigationBar: BilahNavigasiBawah(
        terpilih: _tab,
        onPilih: (indeks) => setState(() => _tab = indeks),
        tujuan: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: jumlahAktif,
              isLabelVisible: jumlahAktif > 0,
              child: const Icon(Icons.person_outline),
            ),
            selectedIcon: Badge.count(
              count: jumlahAktif,
              isLabelVisible: jumlahAktif > 0,
              child: const Icon(Icons.person),
            ),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
