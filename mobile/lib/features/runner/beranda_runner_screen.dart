import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/order.dart';
import '../../providers/runner_providers.dart';
import '../widgets/bilah_navigasi_bawah.dart';
import 'order_masuk/order_masuk_screen.dart';
import 'order_saya/order_saya_runner_screen.dart';
import 'pendapatan/pendapatan_screen.dart';

/// Permukaan runner: tiga layar yang dipakai bergantian sepanjang hari.
///
/// Order Masuk dibuka untuk mencari pekerjaan, Order Saya untuk
/// menyelesaikannya, Pendapatan untuk melihat hasilnya. Ketiganya dipasang di
/// [IndexedStack] supaya berpindah tab tidak membuang keadaan layar, daftar
/// tidak dimuat ulang dari awal setiap kali runner mengintip tab sebelah.
///
/// Pendapatan ditaruh paling kanan, bukan di antara keduanya: dua tab pertama
/// dipakai berulang-ulang dalam satu hari kerja dan berpasangan (cari lalu
/// kerjakan), sedangkan yang ketiga dibuka sesekali dan tidak menuntut tindakan
/// apa pun. Menyelipkannya di tengah berarti memindahkan letak tab yang sudah
/// dihafal jempol runner.
class BerandaRunnerScreen extends ConsumerStatefulWidget {
  const BerandaRunnerScreen({super.key});

  @override
  ConsumerState<BerandaRunnerScreen> createState() =>
      _BerandaRunnerScreenState();
}

class _BerandaRunnerScreenState extends ConsumerState<BerandaRunnerScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final dipegang =
        ref.watch(orderRunnerProvider).value?.isi ?? const <Order>[];
    // Dihitung dari yang terbawa, jadi angkanya ikut jendela daftar. Untuk lencana
    // "berapa yang sedang dikerjakan" itu memang cukup: order yang sedang aktif selalu
    // yang terbaru, dan yang terbaru selalu masuk jendela pertama.
    final jumlahAktif = dipegang.where((o) => o.status.isAktif).length;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const OrderMasukScreen(),
          OrderSayaRunnerScreen(
            onMintaOrderMasuk: () => setState(() => _tab = 0),
          ),
          const PendapatanScreen(),
        ],
      ),
      bottomNavigationBar: BilahNavigasiBawah(
        terpilih: _tab,
        onPilih: (indeks) => setState(() => _tab = indeks),
        tujuan: [
          const NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Order Masuk',
          ),
          NavigationDestination(
            // Pekerjaan yang belum kelar tidak boleh cuma diingat runner
            // sendiri, angkanya menempel di tab sampai ordernya ditutup.
            icon: Badge.count(
              count: jumlahAktif,
              isLabelVisible: jumlahAktif > 0,
              child: const Icon(Icons.assignment_outlined),
            ),
            selectedIcon: Badge.count(
              count: jumlahAktif,
              isLabelVisible: jumlahAktif > 0,
              child: const Icon(Icons.assignment),
            ),
            label: 'Order Saya',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Pendapatan',
          ),
        ],
      ),
    );
  }
}
