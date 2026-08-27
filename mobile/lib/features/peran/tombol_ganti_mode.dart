import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/enums.dart';
import '../../providers/peran_providers.dart';
import '../../providers/repository_providers.dart';

/// Tombol ganti mode untuk akun yang merangkap klien dan runner (bagian 14.3).
///
/// Hanya muncul kalau akunnya memang punya dua permukaan. Akun klien saja,
/// runner saja, atau `[admin, runner]` tidak melihat tombol ini sama sekali,
/// karena tombol yang tidak menuju ke mana-mana cuma mengundang tekanan yang
/// tidak menghasilkan apa-apa.
///
/// Berbeda dari pengalih akun yang bertanda ALAT PENGUJI, tombol ini fitur
/// sungguhan dan tetap ada setelah layar login dipasang. Yang satu mengganti
/// siapa yang masuk, yang ini mengganti pekerjaan apa yang sedang dilakukan
/// orang yang sama.
class TombolGantiMode extends ConsumerWidget {
  const TombolGantiMode({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userAktifProvider).value;
    if (user == null || !user.bisaGantiMode) return const SizedBox.shrink();

    final peranAktif = ref.watch(peranAktifProvider);

    return IconButton(
      onPressed: () => _pilihMode(context, ref, user.peranMobile, peranAktif),
      icon: const Icon(Icons.swap_horiz),
      tooltip: 'Ganti Mode',
    );
  }

  Future<void> _pilihMode(
    BuildContext context,
    WidgetRef ref,
    Set<UserRole> peranMobile,
    UserRole? aktif,
  ) async {
    final dipilih = await showModalBottomSheet<UserRole>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppTheme.spasiSedang),
            Text(
              'Ganti Mode',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spasiBesar,
              ),
              child: Text(
                'Akunmu memegang dua peran sekaligus. Ordermu sendiri dan '
                'order yang kamu kerjakan tidak tercampur, cuma tampilannya '
                'yang berganti.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spasiKecil),
            for (final peran in _urutan.where(peranMobile.contains))
              ListTile(
                leading: Icon(
                  peran == aktif
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text('Mode ${peran.label}'),
                subtitle: Text(_keterangan(peran)),
                onTap: () => Navigator.of(context).pop(peran),
              ),
            const SizedBox(height: AppTheme.spasiKecil),
          ],
        ),
      ),
    );

    if (dipilih == null || dipilih == aktif) return;
    ref.read(peranAktifProvider.notifier).ganti(dipilih);
  }

  /// Urutan tetap supaya posisi pilihannya tidak berpindah-pindah antar akun.
  static const List<UserRole> _urutan = [UserRole.klien, UserRole.runner];

  static String _keterangan(UserRole peran) => switch (peran) {
    UserRole.klien => 'Memesan bantuan untuk keperluanmu sendiri',
    UserRole.runner => 'Mengambil dan mengerjakan order orang lain',
    UserRole.admin => 'Dikerjakan lewat dashboard web',
  };
}
