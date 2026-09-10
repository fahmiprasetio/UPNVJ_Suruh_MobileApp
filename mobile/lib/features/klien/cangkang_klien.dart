import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/order.dart';
import '../../providers/order_providers.dart';
import '../chat/daftar_chat_screen.dart';
import '../widgets/bilah_navigasi_bawah.dart';
import 'beranda/beranda_klien_screen.dart';
import 'riwayat/riwayat_order_screen.dart';

/// Permukaan klien: tiga tempat yang dipakai bergantian.
///
/// Beranda untuk memesan, Pesanan untuk memantau, Chat untuk percakapan yang
/// menempel pada order. Profil bukan tab di sini lagi -- pintunya pindah ke
/// pojok kanan atas beranda (rujukan Gojek/Grab: profil bukan sesuatu yang
/// dibuka bergantian dengan tugas utama, jadi tempatnya bukan bilah bawah).
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

    // Dijumlahkan dari seluruh order, bukan dihitung ulang di [DaftarChatScreen]:
    // angka di bilah bawah harus tetap benar sekalipun tab Chat belum pernah
    // dibuka sama sekali, dan [orderKlienProvider] sudah dipantau di sini juga.
    final belumDibaca = order.fold<int>(
      0,
      (jumlah, o) => jumlah + o.jumlahPesanBelumDibaca,
    );

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
          const DaftarChatScreen(),
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
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: belumDibaca,
              isLabelVisible: belumDibaca > 0,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: Badge.count(
              count: belumDibaca,
              isLabelVisible: belumDibaca > 0,
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
