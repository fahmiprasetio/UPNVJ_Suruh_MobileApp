import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/pembuka/pembuka_overlay.dart';
import 'providers/pembuka_providers.dart';

class UpnvjSuruhApp extends ConsumerWidget {
  const UpnvjSuruhApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'UPNVJ Suruh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.terang(),
      darkTheme: AppTheme.gelap(),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      // `builder` membungkus Navigator, jadi apa pun yang ditumpuk di sini
      // berada di atas seluruh rute sekaligus, termasuk dialog.
      builder: (context, child) => _DenganPembuka(isi: child),
    );
  }
}

/// Menumpuk lapisan pembuka di atas aplikasi yang sudah berjalan di bawahnya.
///
/// Ini inti perbaikan cacat "layar putih sekejap setelah animasi selesai".
/// Selama pembuka masih dipasang, aplikasi yang sesungguhnya tetap ada di dalam
/// pohon widget, ikut dibangun, di-layout, dan digambar, cuma tertutup lapisan
/// putih berlencana di atasnya. Jadi waktu yang dipakai animasi bukan waktu yang
/// terbuang menunggu: di belakangnya halaman berikutnya sedang disiapkan.
///
/// Begitu lapisannya diangkat, yang tersingkap adalah halaman yang sudah jadi,
/// bukan halaman yang baru mulai dibangun. Tidak ada lagi jeda di antara
/// keduanya, karena tidak ada lagi urutan "yang satu pergi dulu, baru yang lain
/// datang".
///
/// Bandingkan dengan bentuk sebelumnya, pembuka sebagai rute `/pembuka`: di sana
/// `GerbangPermukaan` atau `MasukScreen` baru MULAI dibangun setelah pembukanya
/// dilepas, dan sepanjang pembangunan itu yang terlihat adalah sisa layar
/// sebelumnya, yaitu putih polos.
class _DenganPembuka extends ConsumerWidget {
  const _DenganPembuka({required this.isi});

  final Widget? isi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aplikasi = isi ?? const SizedBox.shrink();
    if (ref.watch(statusPembukaProvider)) return aplikasi;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Tertutup mata, tapi tidak boleh ikut tertutup dari pembaca layar
        // dengan cara yang salah: yang benar adalah menyembunyikannya, bukan
        // membiarkannya terbaca sementara penggunanya belum bisa menyentuhnya.
        ExcludeSemantics(child: aplikasi),
        const PembukaOverlay(),
      ],
    );
  }
}
