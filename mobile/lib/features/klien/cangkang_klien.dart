import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/order.dart';
import '../../providers/order_providers.dart';
import '../widgets/bilah_navigasi_bawah.dart';
import 'beranda/beranda_klien_screen.dart';
import 'riwayat/riwayat_order_screen.dart';

/// Permukaan klien: dua tempat yang dipakai bergantian.
///
/// Beranda dibuka untuk memesan, Order Saya dibuka untuk menengok apa yang sudah
/// dipesan. Sebelum ini Order Saya cuma ikon di pojok bilah atas, dan itu salah
/// tempat: memesan dan memantau adalah dua hal yang sama seringnya dilakukan
/// orang, sementara pojok bilah atas adalah tempat yang dipakai untuk hal yang
/// jarang. Permukaan runner sudah lebih dulu berbentuk begini; klien menyusul,
/// dan sekarang keduanya bisa dipelajari sekali.
///
/// Dipasang di [IndexedStack] supaya berpindah tab tidak membuang keadaan layar.
/// Daftar order tidak dimuat ulang dari awal setiap kali pengguna mengintip
/// beranda, dan posisi gulungnya tidak lompat ke atas saat ia kembali.
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
    // menunggu dibayar berhenti di situ sampai ada yang membukanya lagi.
    final jumlahAktif = order.where((o) => o.status.isAktif).length;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const BerandaKlienScreen(),
          // Riwayat yang kosong menawarkan mulai memesan, dan yang dituju tab
          // sebelah, bukan rute baru. Mendorong beranda sebagai rute akan
          // menumpuk dua beranda di riwayat navigasi, dan tombol kembali
          // sesudahnya mengantar pengguna ke beranda kedua yang tidak ia buka.
          RiwayatOrderScreen(onMintaBeranda: () => setState(() => _tab = 0)),
        ],
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
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Badge.count(
              count: jumlahAktif,
              isLabelVisible: jumlahAktif > 0,
              child: const Icon(Icons.receipt_long),
            ),
            label: 'Order Saya',
          ),
        ],
      ),
    );
  }
}
