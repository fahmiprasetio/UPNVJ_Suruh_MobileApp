import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../domain/models/app_user.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/tema_providers.dart';
import '../klien/buka_form_order.dart' show belumTersedia;
import '../profil/atur_password_dialog.dart';
import 'hapus_akun_dialog.dart';

/// Pengaturan aplikasi dengan Desain Modern Gojek Aloha.
///
/// Mengorganisir opsi pengaturan ke dalam kartu-kartu terkelompok rapi
/// (Preferensi Aplikasi, Keamanan, Pusat Bantuan & Legal, serta Zona Berbahaya),
/// dilengkapi ikon squircle pastel khas Gojek, tipografi tegas, dan transisi halus.
class PengaturanScreen extends ConsumerWidget {
  const PengaturanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeTemaProvider);
    final user = ref.watch(userAktifProvider).value;
    final skema = Theme.of(context).colorScheme;
    final gelap = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: gelap ? skema.surface : const Color(0xFFF7F9FA),
      appBar: AppBar(
        backgroundColor: gelap ? skema.surface : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: gelap
                    ? const Color(0xFF1B381E)
                    : const Color(0xFFE8F8EA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: Color(0xFF00AA13),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengaturan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: gelap ? skema.onSurface : const Color(0xFF1F2937),
                  ),
                ),
                Text(
                  'Preferensi & Keamanan Akun',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: gelap
                        ? skema.onSurfaceVariant
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Seksi: Preferensi Aplikasi
          _buildSectionHeader(context, 'PREFERENSI APLIKASI'),
          _buildCardGroup(
            context: context,
            children: [
              _buildTileItem(
                context: context,
                ikon: Icons.notifications_rounded,
                warnaIkonLatar: const Color(0xFFE8F8EA),
                warnaIkon: const Color(0xFF00AA13),
                judul: 'Notifikasi',
                subjudul: 'Pemberitahuan pesanan dan chat',
                onTap: () => context.push(Rute.notifikasi),
              ),
              _buildTileItem(
                context: context,
                ikon: Icons.palette_outlined,
                warnaIkonLatar: const Color(0xFFEFF6FF),
                warnaIkon: const Color(0xFF2563EB),
                judul: 'Tampilan',
                subjudul: _labelMode(mode),
                onTap: () => _pilihTema(context, ref, mode),
              ),
              _pintuMenyusul(
                context,
                Icons.language_rounded,
                const Color(0xFFF3E8FF),
                const Color(0xFF9333EA),
                'Bahasa',
                'Bahasa Indonesia',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 2. Seksi: Keamanan & Akun
          if (user != null) ...[
            _buildSectionHeader(context, 'KEAMANAN & AKUN'),
            _buildCardGroup(
              context: context,
              children: [
                _buildTileItem(
                  context: context,
                  ikon: Icons.lock_outline_rounded,
                  warnaIkonLatar: const Color(0xFFFEF3C7),
                  warnaIkon: const Color(0xFFD97706),
                  judul: 'Password',
                  subjudul: user.punyaPassword
                      ? 'Wajib bersama OTP setiap kali masuk'
                      : 'Atur sekarang agar login berikutnya memakai dua langkah',
                  onTap: () => _aturPassword(context, ref, user),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // 3. Seksi: Pusat Bantuan & Legal
          _buildSectionHeader(context, 'PUSAT BANTUAN & INFORMASI'),
          _buildCardGroup(
            context: context,
            children: [
              _buildTileItem(
                context: context,
                ikon: Icons.help_outline_rounded,
                warnaIkonLatar: const Color(0xFFE0F2FE),
                warnaIkon: const Color(0xFF0284C7),
                judul: 'Pusat Bantuan',
                subjudul: 'FAQ dan kontak admin',
                onTap: () => context.push(Rute.pusatBantuan),
              ),
              _buildTileItem(
                context: context,
                ikon: Icons.description_outlined,
                warnaIkonLatar: const Color(0xFFF1F5F9),
                warnaIkon: const Color(0xFF475569),
                judul: 'Syarat & Ketentuan',
                onTap: () => context.push(Rute.syaratKetentuan),
              ),
              _buildTileItem(
                context: context,
                ikon: Icons.verified_user_outlined,
                warnaIkonLatar: const Color(0xFFECFDF5),
                warnaIkon: const Color(0xFF059669),
                judul: 'Kebijakan Privasi',
                onTap: () => context.push(Rute.kebijakanPrivasi),
              ),
              _buildTileItem(
                context: context,
                ikon: Icons.info_outline_rounded,
                warnaIkonLatar: const Color(0xFFF8FAFC),
                warnaIkon: const Color(0xFF64748B),
                judul: 'Tentang Aplikasi',
                onTap: () => context.push(Rute.tentangAplikasi),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4. Seksi: Zona Berbahaya
          if (user != null) ...[
            _buildSectionHeader(context, 'ZONA BERBAHAYA'),
            _buildCardGroup(
              context: context,
              children: [
                _buildTileItem(
                  context: context,
                  ikon: Icons.delete_forever_rounded,
                  warnaIkonLatar: const Color(0xFFFEE2E2),
                  warnaIkon: const Color(0xFFDC2626),
                  judul: 'Hapus Akun',
                  subjudul: 'Hapus akun dan data pribadimu',
                  warnaTeksKhusus: Theme.of(context).colorScheme.error,
                  onTap: () => _hapusAkun(context, user),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String judul) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        judul,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: gelap
              ? Theme.of(context).colorScheme.primary
              : const Color(0xFF00AA13),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCardGroup({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final skema = Theme.of(context).colorScheme;
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final warnaKartu = gelap ? skema.surfaceContainerHigh : Colors.white;
    final warnaBorder = gelap
        ? skema.outlineVariant.withValues(alpha: 0.3)
        : const Color(0xFFE5E7EB);

    return Material(
      color: warnaKartu,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: warnaBorder, width: 1.2),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: gelap
                    ? skema.outlineVariant.withValues(alpha: 0.2)
                    : const Color(0xFFF3F4F6),
                indent: 68,
                endIndent: 16,
              ),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _buildTileItem({
    required BuildContext context,
    required IconData ikon,
    required Color warnaIkonLatar,
    required Color warnaIkon,
    required String judul,
    String? subjudul,
    Widget? trailing,
    VoidCallback? onTap,
    Color? warnaTeksKhusus,
  }) {
    final skema = Theme.of(context).colorScheme;
    final gelap = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: gelap
                ? warnaIkonLatar.withValues(alpha: 0.2)
                : warnaIkonLatar,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            ikon,
            color: warnaIkon,
            size: 20,
          ),
        ),
        title: Text(
          judul,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: warnaTeksKhusus ??
                (gelap ? skema.onSurface : const Color(0xFF1F2937)),
          ),
        ),
        subtitle: subjudul == null
            ? null
            : Text(
                subjudul,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: gelap
                      ? skema.onSurfaceVariant
                      : const Color(0xFF6B7280),
                ),
              ),
        trailing: trailing ??
            Icon(
              Icons.chevron_right_rounded,
              color: gelap
                  ? skema.onSurfaceVariant
                  : const Color(0xFF9CA3AF),
              size: 22,
            ),
        onTap: onTap,
      ),
    );
  }

  Widget _pintuMenyusul(
    BuildContext context,
    IconData ikon,
    Color warnaLatar,
    Color warnaIkon,
    String judul,
    String? keterangan,
  ) {
    return _buildTileItem(
      context: context,
      ikon: ikon,
      warnaIkonLatar: warnaLatar,
      warnaIkon: warnaIkon,
      judul: judul,
      subjudul: keterangan,
      onTap: () => belumTersedia(context, judul),
    );
  }

  static String _labelMode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Terang',
    ThemeMode.dark => 'Gelap',
    ThemeMode.system => 'Ikuti sistem',
  };

  Future<void> _hapusAkun(BuildContext context, AppUser user) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => HapusAkunDialog(noHp: user.noHp),
    );
  }

  Future<void> _aturPassword(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
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
              leading: Icon(
                mode == sekarang
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: mode == sekarang ? const Color(0xFF00AA13) : null,
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
