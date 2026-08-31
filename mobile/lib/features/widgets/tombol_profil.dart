import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

/// Pintu ke profil, dan lewat profil ke satu-satunya jalan keluar dari akun.
///
/// Berkas sendiri, bukan widget privat di beranda klien, karena permukaan
/// runner membutuhkannya juga. Sebelum ini pintunya cuma ada di beranda klien,
/// jadi akun runner murni tidak punya cara keluar sama sekali, dan itu separuh
/// pengguna aplikasi ini.
class TombolProfil extends StatelessWidget {
  const TombolProfil({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => context.push(Rute.profil),
      icon: const Icon(Icons.person_outline),
      tooltip: 'Profil',
    );
  }
}
