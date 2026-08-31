import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/galat_api.dart';
import '../domain/enums.dart';
import '../providers/peran_providers.dart';
import '../providers/repository_providers.dart';
import 'dev/pengalih_akun.dart';
import 'klien/cangkang_klien.dart';
import 'runner/beranda_runner_screen.dart';
import 'widgets/pesan_kosong.dart';
import 'widgets/tombol_profil.dart';

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
      error: (galat, _) => _PermukaanKosong(
        ikon: Icons.wifi_off_outlined,
        judul: 'Akun gagal dimuat',
        // Kalimat yang memang ditulis untuk dibaca orang kalau ada, jejak
        // pengecualian mentah tidak pernah. Ini layar pertama sesudah masuk,
        // dan nama kelas Dart di situ cuma memberi kesan aplikasinya rusak
        // lebih parah daripada sebenarnya.
        pesan: galat is GalatApi
            ? galat.pesan
            : 'Sambungan ke server terputus.',
      ),
      data: (user) {
        // Layar kosong, bukan kalimat.
        //
        // Dulu di sini tertulis "Belum masuk. Layar login menyusul.", kalimat
        // yang sudah salah sejak layar masuk dipasang. Sekarang keadaan ini
        // hampir tidak pernah terlihat: `redirect` di router mengantar yang
        // belum masuk ke `/masuk` sebelum layar ini sempat digambar. Yang
        // pantas mengisi sepersekian detik itu bukan kalimat apa pun,
        // melainkan tidak ada apa-apa, karena kalimat yang sempat terbaca
        // sekejap lalu hilang lebih mengganggu daripada layar yang diam.
        if (user == null) return const Scaffold();

        return switch (ref.watch(peranAktifProvider)) {
          UserRole.klien => const CangkangKlien(),
          UserRole.runner => const BerandaRunnerScreen(),
          // Peran admin tidak punya permukaan mobile, dan akun yang cuma
          // memegang admin tidak punya peran bawaan sama sekali.
          _ => const _PermukaanKosong(
            ikon: Icons.desktop_windows_outlined,
            judul: 'Akun admin',
            pesan:
                'Pekerjaan admin dilakukan lewat dashboard web, bukan '
                'aplikasi ini. Tidak ada yang bisa dikerjakan dari sini.',
          ),
        };
      },
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
        actions: const [PengalihAkun(), TombolProfil()],
      ),
      // Widget kosong yang sama dengan daftar order dan chat, bukan salinan
      // keempat.
      body: PesanKosong(ikon: ikon, judul: judul, keterangan: pesan),
    );
  }
}
