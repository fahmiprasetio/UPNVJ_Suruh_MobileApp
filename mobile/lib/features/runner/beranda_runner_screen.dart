import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/order.dart';
import '../../providers/runner_providers.dart';
import 'order_masuk/order_masuk_screen.dart';
import 'order_saya/order_saya_runner_screen.dart';

/// Permukaan runner: dua daftar yang dipakai bergantian sepanjang hari.
///
/// Order Masuk dibuka untuk mencari pekerjaan, Order Saya dibuka untuk
/// menyelesaikannya. Keduanya dipasang di [IndexedStack] supaya berpindah tab
/// tidak membuang keadaan layar, daftar tidak dimuat ulang dari awal setiap
/// kali runner mengintip tab sebelah.
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
    final dipegang = ref.watch(orderRunnerProvider).value ?? const <Order>[];
    final jumlahAktif = dipegang.where((o) => o.status.isAktif).length;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [OrderMasukScreen(), OrderSayaRunnerScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (indeks) => setState(() => _tab = indeks),
        destinations: [
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
        ],
      ),
    );
  }
}
