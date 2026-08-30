import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/halaman.dart';
import '../../providers/ukuran_daftar.dart';

/// Jalan menuju baris yang belum terbawa.
///
/// Daftar sekarang berbatas: server mengirim sepotong, bukan seluruhnya. Tanpa tombol
/// ini, potongan itu jadi batas yang tidak bisa dilewati siapa pun, dan riwayat lama
/// hilang tanpa ada yang memberitahu bahwa ia pernah ada.
///
/// Menghilang sendiri ketika tidak ada sisanya, jadi daftar yang memang pendek tidak
/// memajang tombol yang tidak melakukan apa-apa. Jumlah sisanya ikut disebut, karena
/// "muat lagi" tanpa angka tidak memberi tahu apakah yang tersisa dua atau dua ratus.
class TombolMuatLagi extends ConsumerWidget {
  const TombolMuatLagi({
    super.key,
    required this.halaman,
    required this.ukuranProvider,
  });

  final Halaman<Object?> halaman;
  final NotifierProvider<UkuranDaftar, int> ukuranProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!halaman.adaSisa) return const SizedBox.shrink();

    final sisa = halaman.total - halaman.isi.length;
    final bisaDiperbesar = ref.watch(ukuranProvider.notifier).bisaDiperbesar;

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spasiSedang),
      child: Center(
        child: bisaDiperbesar
            ? OutlinedButton(
                onPressed: () => ref.read(ukuranProvider.notifier).perbesar(),
                child: Text('Muat $sisa order lagi'),
              )
            // Jendelanya sudah mentok di batas yang diterima server. Mengaku terus
            // terang, bukan memajang tombol yang ditekan tapi tidak mengubah apa pun.
            : Text(
                'Masih ada $sisa order lama yang belum bisa ditampilkan di sini.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
