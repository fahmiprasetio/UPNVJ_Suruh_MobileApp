import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../core/api/galat_api.dart';
import '../core/router/app_router.dart';
import '../domain/enums.dart';
import '../core/providers/peran_providers.dart';
import '../core/providers/repository_providers.dart';
import 'klien/cangkang_klien.dart';
import 'runner/beranda_runner_screen.dart';
import '../core/widgets/pesan_kosong.dart';
import '../core/widgets/tombol_profil.dart';

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
    final repo = ref.watch(authRepositoryProvider);
    final userAktifAsync = ref.watch(userAktifProvider);
    final user = userAktifAsync.value ?? repo.userAktif;

    if (user != null) {
      final peran = ref.watch(peranAktifProvider) ?? user.peranBawaan;
      if (peran == null) {
        return const _PermukaanKosong(
          ikon: Icons.desktop_windows_outlined,
          judul: 'Akun admin',
          pesan:
              'Pekerjaan admin dilakukan lewat dashboard web, bukan '
              'aplikasi ini. Tidak ada yang bisa dikerjakan dari sini.',
        );
      }
      return switch (peran) {
        UserRole.klien => const CangkangKlien(),
        UserRole.runner => const BerandaRunnerScreen(),
        _ => const _PermukaanKosong(
          ikon: Icons.desktop_windows_outlined,
          judul: 'Akun admin',
          pesan:
              'Pekerjaan admin dilakukan lewat dashboard web, bukan '
              'aplikasi ini. Tidak ada yang bisa dikerjakan dari sini.',
        ),
      };
    }

    if (userAktifAsync.hasError) {
      final galat = userAktifAsync.error;
      return Scaffold(
        appBar: AppBar(
          title: const Text('UPNVJ Suruh'),
          actions: const [TombolProfil()],
        ),
        body: PesanKosong(
          ikon: Icons.wifi_off_outlined,
          judul: 'Akun gagal dimuat',
          keterangan: galat is GalatApi
              ? galat.pesan
              : 'Sambungan ke server terputus.',
          labelAksi: 'Coba lagi',
          onAksi: () => ref.invalidate(userAktifProvider),
        ),
      );
    }

    if (!ref.watch(sesiTokenProvider).adaSesi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(Rute.masuk);
        }
      });
      return const Scaffold();
    }

    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFF00AA13))),
    );
  }
}

/// Layar untuk keadaan yang tidak punya permukaan.
///
/// Bilah atasnya membawa tombol profil, dan itu bukan hiasan. Sebelum ini akun
/// yang cuma memegang peran admin sampai di layar ini, membaca bahwa tidak ada
/// yang bisa ia kerjakan, lalu **tidak punya satu pun cara keluar dari akunnya**:
/// tombol profil hanya ada di beranda klien dan bilah atas runner, dan layar ini
/// bukan keduanya. Jalan buntu yang bahkan tidak bisa ditinggalkan.
class _PermukaanKosong extends StatelessWidget {
  const _PermukaanKosong({
    required this.ikon,
    required this.judul,
    required this.pesan,
  });

  final IconData ikon;
  final String judul;
  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPNVJ Suruh'),
        actions: const [TombolProfil()],
      ),
      // Widget kosong yang sama dengan daftar order dan chat, bukan salinan
      // keempat.
      body: PesanKosong(ikon: ikon, judul: judul, keterangan: pesan),
    );
  }
}
