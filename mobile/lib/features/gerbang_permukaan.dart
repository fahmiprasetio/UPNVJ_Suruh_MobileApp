import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../providers/repository_providers.dart';
import 'dev/pengalih_akun.dart';
import 'klien/beranda/beranda_klien_screen.dart';
import 'runner/order_masuk/order_masuk_screen.dart';

/// Penentu permukaan mana yang terbuka setelah masuk.
///
/// Klien dan runner tinggal di satu aplikasi; yang membedakan bukan aplikasi
/// yang dipasang, melainkan peran akunnya (rencana capstone bagian 14.1).
/// Admin tidak punya permukaan mobile sama sekali — pekerjaannya adalah
/// pekerjaan tabel dan angka yang tempatnya di dashboard web (bagian 14.2).
///
/// Akun yang memegang peran klien sekaligus runner untuk sementara dibuka
/// sebagai klien. Tombol ganti mode yang sebenarnya (bagian 14.3) menyusul
/// bersama layar login, karena keduanya menyentuh persoalan yang sama: cara
/// aplikasi tahu sedang melayani siapa.
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
        if (user.isKlien) return const BerandaKlienScreen();
        if (user.isRunner) return const OrderMasukScreen();
        return const _PermukaanKosong(
          pesan:
              'Akun ini hanya punya peran admin. Pekerjaan admin dilakukan '
              'lewat dashboard web, bukan aplikasi ini.',
        );
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
