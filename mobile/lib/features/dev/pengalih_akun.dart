import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/app_user.dart';
import '../../providers/repository_providers.dart';

/// Alat penguji untuk berpindah akun, sepadan dengan panel simulator di layar
/// pembayaran.
///
/// Layar login belum bisa dibuat karena cara masuk akun masih menunggu jawaban
/// mitra (rencana capstone bagian 14.8), sementara sisi runner tidak ada
/// gunanya kalau tidak bisa dibuka sama sekali. Tombol ini menutup jurang itu
/// tanpa mengarang alur login: ia hilang dengan sendirinya begitu autentikasi
/// sungguhan terpasang, karena penyedianya mengembalikan `null`.
class PengalihAkun extends ConsumerWidget {
  const PengalihAkun({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final akunUji = ref.watch(akunUjiProvider);
    if (akunUji == null) return const SizedBox.shrink();
    if (ref.watch(pengalihAkunProvider) == null) return const SizedBox.shrink();

    return IconButton(
      onPressed: () => _pilihAkun(context, ref, akunUji),
      icon: const Icon(Icons.science_outlined),
      tooltip: 'Ganti Akun (alat penguji)',
    );
  }

  Future<void> _pilihAkun(
    BuildContext context,
    WidgetRef ref,
    List<AppUser> akunUji,
  ) async {
    final aktif = ref.read(userAktifProvider).value;

    final dipilih = await showModalBottomSheet<AppUser>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppTheme.spasiSedang),
            Text(
              'ALAT PENGUJI: GANTI AKUN',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppTheme.spasiKecil),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spasiBesar,
              ),
              child: Text(
                'Menggantikan layar login yang bentuknya belum diputuskan. '
                'Peran akun menentukan tampilan yang terbuka.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spasiKecil),
            for (final akun in akunUji)
              ListTile(
                leading: Icon(
                  akun.id == aktif?.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(akun.nama),
                subtitle: Text(
                  akun.roles.map((r) => r.label).join(' + '),
                ),
                onTap: () => Navigator.of(context).pop(akun),
              ),
            const SizedBox(height: AppTheme.spasiKecil),
          ],
        ),
      ),
    );

    if (dipilih == null || dipilih.id == aktif?.id) return;
    ref.read(pengalihAkunProvider)?.call(dipilih);
  }
}
