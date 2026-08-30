import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../domain/enums.dart';
import '../providers/peran_providers.dart';
import '../providers/repository_providers.dart';
import 'dev/pengalih_akun.dart';
import 'klien/cangkang_klien.dart';
import 'runner/beranda_runner_screen.dart';

/// Penentu permukaan mana yang terbuka setelah masuk.
///
/// Klien dan runner tinggal di satu aplikasi; yang membedakan bukan aplikasi
/// yang dipasang, melainkan peran akunnya (rencana capstone bagian 14.1).
/// Admin tidak punya permukaan mobile sama sekali, pekerjaannya adalah
/// pekerjaan tabel dan angka yang tempatnya di dashboard web (bagian 14.2).
///
/// Akun yang memegang peran klien sekaligus runner dibuka sebagai klien, lalu
/// bisa berpindah lewat tombol ganti mode (bagian 14.3). Yang menentukan
/// permukaan bukan lagi daftar perannya, melainkan peran mana yang sedang
/// dipakai, satu nilai yang disimpan di `peranAktifProvider`.
class GerbangPermukaan extends ConsumerWidget {
  const GerbangPermukaan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userAktifProvider);

    return user.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (galat, _) => _PermukaanKosong(pesan: 'Gagal memuat akun: $galat'),
      data: (user) {
        if (user == null) {
          return const _PermukaanKosong(
            pesan: 'Belum masuk. Layar login menyusul.',
          );
        }
        return switch (ref.watch(peranAktifProvider)) {
          UserRole.klien => const CangkangKlien(),
          UserRole.runner => const BerandaRunnerScreen(),
          // Peran admin tidak punya permukaan mobile, dan akun yang cuma
          // memegang admin tidak punya peran bawaan sama sekali.
          _ => const _PermukaanKosong(
            pesan:
                'Akun ini hanya punya peran admin. Pekerjaan admin dilakukan '
                'lewat dashboard web, bukan aplikasi ini.',
          ),
        };
      },
    );
  }
}

class _PermukaanKosong extends StatelessWidget {
  const _PermukaanKosong({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPNVJ Suruh'),
        actions: const [PengalihAkun()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spasiBesar),
          child: Text(
            pesan,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
