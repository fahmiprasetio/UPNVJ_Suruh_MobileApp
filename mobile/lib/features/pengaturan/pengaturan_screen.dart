import 'package:flutter/material.dart';

import '../klien/buka_form_order.dart' show belumTersedia;

/// Pengaturan aplikasi.
///
/// Cuma daftar pintu untuk sekarang, tanpa satu pun yang fungsinya sungguhan
/// -- ketukannya menjawab "menyusul", sama seperti pintu order yang formnya
/// belum ada di [belumTersedia]. Isinya dipilih dari yang lazim ada di
/// pengaturan aplikasi lain: notifikasi, tampilan, bahasa, sampai bantuan.
/// Aplikasi ini tidak punya kata sandi (masuk cuma lewat OTP), jadi tidak
/// ada butir ubah kata sandi di sini.
class PengaturanScreen extends StatelessWidget {
  const PengaturanScreen({super.key});

  static const _butir = [
    (Icons.notifications_outlined, 'Notifikasi', 'Pemberitahuan pesanan dan chat'),
    (Icons.dark_mode_outlined, 'Tampilan', 'Tema terang, gelap, atau ikuti sistem'),
    (Icons.language_outlined, 'Bahasa', 'Bahasa Indonesia'),
    (Icons.lock_outline, 'Privasi & Keamanan', null),
    (Icons.help_outline, 'Pusat Bantuan', null),
    (Icons.description_outlined, 'Syarat & Ketentuan', null),
    (Icons.privacy_tip_outlined, 'Kebijakan Privasi', null),
    (Icons.info_outline, 'Tentang Aplikasi', null),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView.separated(
        itemCount: _butir.length,
        separatorBuilder: (context, indeks) => const Divider(height: 1),
        itemBuilder: (context, indeks) {
          final (ikon, judul, keterangan) = _butir[indeks];
          return ListTile(
            leading: Icon(ikon),
            title: Text(judul),
            subtitle: keterangan == null ? null : Text(keterangan),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => belumTersedia(context, judul),
          );
        },
      ),
    );
  }
}
