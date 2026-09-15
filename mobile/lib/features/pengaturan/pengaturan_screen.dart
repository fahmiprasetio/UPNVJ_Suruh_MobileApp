import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_user.dart';
import '../../providers/repository_providers.dart';
import '../../providers/tema_providers.dart';
import '../klien/buka_form_order.dart' show belumTersedia;
import '../profil/atur_password_dialog.dart';

/// Pengaturan aplikasi.
///
/// Sebagian besar masih daftar pintu yang menjawab "menyusul", sama seperti
/// pintu order yang formnya belum ada di [belumTersedia]. Yang sudah sungguhan
/// cuma Tampilan: ia mengganti tema saat itu juga dan pilihannya bertahan
/// sampai aplikasi dibuka lagi.
class PengaturanScreen extends ConsumerWidget {
  const PengaturanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeTemaProvider);
    final user = ref.watch(userAktifProvider).value;

    final butir = <Widget>[
      _pintuMenyusul(
        context,
        Icons.notifications_outlined,
        'Notifikasi',
        'Pemberitahuan pesanan dan chat',
      ),
      ListTile(
        leading: const Icon(Icons.dark_mode_outlined),
        title: const Text('Tampilan'),
        subtitle: Text(_labelMode(mode)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pilihTema(context, ref, mode),
      ),
      _pintuMenyusul(
        context,
        Icons.language_outlined,
        'Bahasa',
        'Bahasa Indonesia',
      ),
      if (user != null)
        ListTile(
          leading: const Icon(Icons.password_outlined),
          title: const Text('Password'),
          subtitle: Text(
            user.punyaPassword
                ? 'Sudah diatur, jalur masuk kedua di samping OTP'
                : 'Belum diatur, masuk masih lewat OTP',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _aturPassword(context, ref, user),
        ),
      _pintuMenyusul(context, Icons.help_outline, 'Pusat Bantuan', null),
      _pintuMenyusul(
        context,
        Icons.description_outlined,
        'Syarat & Ketentuan',
        null,
      ),
      _pintuMenyusul(
        context,
        Icons.privacy_tip_outlined,
        'Kebijakan Privasi',
        null,
      ),
      _pintuMenyusul(context, Icons.info_outline, 'Tentang Aplikasi', null),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView.separated(
        itemCount: butir.length,
        separatorBuilder: (context, indeks) => const Divider(height: 1),
        itemBuilder: (context, indeks) => butir[indeks],
      ),
    );
  }

  Widget _pintuMenyusul(
    BuildContext context,
    IconData ikon,
    String judul,
    String? keterangan,
  ) {
    return ListTile(
      leading: Icon(ikon),
      title: Text(judul),
      subtitle: keterangan == null ? null : Text(keterangan),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => belumTersedia(context, judul),
    );
  }

  static String _labelMode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Terang',
    ThemeMode.dark => 'Gelap',
    ThemeMode.system => 'Ikuti sistem',
  };

  Future<void> _aturPassword(BuildContext context, WidgetRef ref, AppUser user) async {
    await showDialog<AppUser>(
      context: context,
      builder: (context) => AturPasswordDialog(
        noHp: user.noHp,
        sudahPunyaPassword: user.punyaPassword,
      ),
    );
  }

  Future<void> _pilihTema(
    BuildContext context,
    WidgetRef ref,
    ThemeMode sekarang,
  ) async {
    final pilihan = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Tampilan'),
        children: [
          for (final mode in ThemeMode.values)
            ListTile(
              // Lingkaran terisi, bukan widget Radio bawaan: API radio Material
              // sedang berpindah bentuk di Flutter stable, dan daftar sependek
              // ini tidak membutuhkannya untuk terbaca.
              leading: Icon(
                mode == sekarang
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(_labelMode(mode)),
              onTap: () => Navigator.of(context).pop(mode),
            ),
        ],
      ),
    );

    if (pilihan == null) return;
    ref.read(modeTemaProvider.notifier).pilih(pilihan);
  }
}
