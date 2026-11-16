import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/repository_providers.dart';
import '../tracking/pelacak_runner.dart';

/// Izin lokasi diperbaiki dari tab/perangkat runner yang sedang membagikannya.
class StatusLokasiRunner extends ConsumerWidget {
  const StatusLokasiRunner({super.key, required this.runnerIds});

  final List<String> runnerIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userAktifProvider).value;
    if (user == null || !runnerIds.contains(user.id)) {
      return const SizedBox.shrink();
    }
    final pelacak = ref.watch(pelacakRunnerProvider);
    if (pelacak == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: pelacak,
      builder: (context, _) {
        final status = pelacak.status;
        final sibuk =
            status == StatusPelacakanRunner.memintaIzin ||
            status == StatusPelacakanRunner.mencariLokasi;
        final aktif = status == StatusPelacakanRunner.membagikanLokasi;
        final pesan = switch (status) {
          StatusPelacakanRunner.nonaktif =>
            'Aktifkan lokasi untuk perjalanan ini.',
          StatusPelacakanRunner.memintaIzin =>
            'Memeriksa izin lokasi runner...',
          StatusPelacakanRunner.mencariLokasi => 'Mengambil lokasi runner...',
          StatusPelacakanRunner.membagikanLokasi =>
            'Lokasimu sedang dibagikan kepada klien.',
          StatusPelacakanRunner.izinDitolak =>
            'Izinkan Lokasi pada pengaturan situs di jendela runner, lalu coba lagi.',
          StatusPelacakanRunner.layananNonaktif =>
            'Aktifkan layanan lokasi perangkat, lalu coba lagi.',
          StatusPelacakanRunner.lokasiTidakTersedia =>
            'Lokasi belum terbaca. Periksa izin lokasi dan coba lagi.',
          StatusPelacakanRunner.akurasiRendah =>
            'Lokasi belum cukup akurat. Aktifkan lokasi presisi lalu coba lagi.',
          StatusPelacakanRunner.pengirimanTertunda =>
            'Pengiriman lokasi tertunda. Periksa koneksi dan coba lagi.',
        };

        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              if (sibuk)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  aktif
                      ? Icons.location_on_outlined
                      : Icons.location_off_outlined,
                  size: 20,
                  color: const Color(0xFF006C0E),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pesan,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF14532D),
                  ),
                ),
              ),
              if (!sibuk && !aktif)
                TextButton(
                  onPressed: pelacak.cobaLagi,
                  child: const Text('Coba lagi'),
                ),
            ],
          ),
        );
      },
    );
  }
}
