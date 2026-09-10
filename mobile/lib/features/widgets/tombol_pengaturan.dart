import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

/// Pintu ke pengaturan aplikasi, dari pojok bilah atas beranda.
///
/// Menggantikan [TombolProfil] di beranda klien sejak profil pindah ke bilah
/// navigasi bawah: dua pintu ke tempat yang sama di satu layar cuma
/// membingungkan.
class TombolPengaturan extends StatelessWidget {
  const TombolPengaturan({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => context.push(Rute.pengaturan),
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Pengaturan',
    );
  }
}
