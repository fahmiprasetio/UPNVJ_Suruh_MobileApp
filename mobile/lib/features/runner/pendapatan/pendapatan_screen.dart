import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/format/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/pendapatan.dart';
import '../../../domain/service_catalog.dart';
import '../../../providers/repository_providers.dart';
import '../../dev/pengalih_akun.dart';
import '../../peran/tombol_ganti_mode.dart';
import '../../widgets/pesan_kosong.dart';
import '../../widgets/tombol_profil.dart';

/// Pendapatan runner: berapa yang belum dibayarkan organisasi.
///
/// Layar terakhir dari daftar runner di rencana capstone bagian 14.3, dan
/// satu-satunya di daftar itu yang tidak menuntut runner melakukan apa pun.
/// Gunanya menjawab satu pertanyaan yang selama ini cuma bisa ditanyakan lewat
/// chat: berapa yang masih saya tunggu.
///
/// ## Runner tidak bisa menandai bayarannya sendiri lunas
///
/// Tidak ada tombol apa pun di sini selain menyegarkan. Yang mencatat bahwa uang
/// sudah diserahkan adalah admin lewat dashboard, karena penyerahannya sendiri
/// terjadi di luar sistem, tunai atau transfer antar orang. Tombol "sudah saya
/// terima" di sisi runner akan membuat catatan itu bisa ditulis oleh pihak yang
/// diuntungkan olehnya.
class PendapatanScreen extends ConsumerWidget {
  const PendapatanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendapatan = ref.watch(pendapatanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendapatan Saya'),
        actions: const [TombolGantiMode(), PengalihAkun(), TombolProfil()],
      ),
      body: SafeArea(
        child: pendapatan.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (galat, _) => PesanKosong(
            ikon: Icons.wifi_off_outlined,
            judul: 'Pendapatan gagal dimuat',
            keterangan: galat is GalatApi
                ? galat.pesan
                : 'Sambungan ke server terputus.',
            labelAksi: 'Coba lagi',
            onAksi: () => ref.invalidate(pendapatanProvider),
          ),
          data: (isi) => RefreshIndicator(
            // Satu-satunya cara menyegarkan layar ini, dan itu memang cukup:
            // yang mengubah angkanya adalah admin yang menandai lunas, dan itu
            // terjadi sekali seminggu, bukan sepanjang hari (lihat
            // [pendapatanProvider]).
            onRefresh: () async => ref.refresh(pendapatanProvider.future),
            child: _Isi(pendapatan: isi),
          ),
        ),
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.pendapatan});

  final Pendapatan pendapatan;

  @override
  Widget build(BuildContext context) {
    if (pendapatan.kosong) {
      // Tetap di dalam daftar yang bisa digulung, bukan dipasang begitu saja:
      // RefreshIndicator hanya bisa ditarik di atas sesuatu yang menggulung,
      // dan layar kosong justru yang paling mungkin ingin ditarik.
      return ListView(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        children: const [
          SizedBox(height: AppTheme.spasiBesar),
          PesanKosong(
            ikon: Icons.account_balance_wallet_outlined,
            judul: 'Belum ada pendapatan',
            keterangan:
                'Order yang sudah kamu selesaikan akan muncul di sini '
                'beserta bayarannya.',
          ),
        ],
      );
    }

    final belum = pendapatan.rincian.isi.where((b) => !b.sudahDibayar).toList();
    final sudah = pendapatan.rincian.isi.where((b) => b.sudahDibayar).toList();

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      children: [
        _KartuRingkasan(pendapatan: pendapatan),
        const SizedBox(height: AppTheme.spasiSedang),
        if (belum.isNotEmpty) ..._bagian(context, 'Belum dibayarkan', belum),
        if (sudah.isNotEmpty) ..._bagian(context, 'Sudah dibayarkan', sudah),
      ],
    );
  }

  List<Widget> _bagian(
    BuildContext context,
    String judul,
    List<BarisPendapatan> baris,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
        child: Text(
          '$judul (${baris.length})',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      for (final b in baris)
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
          child: _KartuBaris(baris: b),
        ),
      const SizedBox(height: AppTheme.spasiSedang),
    ];
  }
}

/// Dua angka besar di atas: yang masih ditunggu, dan yang sudah diterima.
///
/// Yang belum dibayar ditaruh lebih dulu dan lebih besar, karena itulah yang
/// sedang ditanyakan orang yang membuka layar ini. Yang sudah diterima ada
/// sebagai pembanding, bukan sebagai kabar baru.
class _KartuRingkasan extends StatelessWidget {
  const _KartuRingkasan({required this.pendapatan});

  final Pendapatan pendapatan;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Belum dibayarkan', style: teks.labelMedium),
            const SizedBox(height: 4),
            Text(
              formatRupiah(pendapatan.totalBelumDibayar),
              style: teks.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: teks.bodySmall?.color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sudah diterima: '
                    '${formatRupiah(pendapatan.totalSudahDibayar)}',
                    style: teks.bodySmall,
                  ),
                ),
              ],
            ),
            if (pendapatan.menungguRumus > 0) ...[
              const SizedBox(height: AppTheme.spasiSedang),
              _CatatanMenungguRumus(jumlah: pendapatan.menungguRumus),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kabar bahwa sebagian order belum punya angka bayaran sama sekali.
///
/// Ada karena tanpanya layar ini berbohong dengan diam: runner yang sudah
/// menyelesaikan lima order lalu membaca "Belum dibayarkan: Rp 0" akan mengira
/// pekerjaannya tidak dihitung, padahal yang belum ada cuma rumus bagi hasil
/// yang harus diisi admin. Bedanya besar, dan cuma bisa diketahui kalau
/// dikatakan.
class _CatatanMenungguRumus extends StatelessWidget {
  const _CatatanMenungguRumus({required this.jumlah});

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    final warna = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spasiKecil),
      decoration: BoxDecoration(
        color: warna.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.spasiKecil),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_empty, size: 16, color: warna.onSurfaceVariant),
          const SizedBox(width: AppTheme.spasiKecil),
          Expanded(
            child: Text(
              '$jumlah order sudah selesai tapi bayarannya belum dihitung. '
              'Admin belum menetapkan bagi hasilnya.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuBaris extends StatelessWidget {
  const _KartuBaris({required this.baris});

  final BarisPendapatan baris;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final layanan = serviceInfoOf(baris.layanan);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Row(
          children: [
            Icon(layanan.icon, size: 22),
            const SizedBox(width: AppTheme.spasiSedang),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    layanan.nama,
                    style: teks.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    baris.selesaiPada == null
                        ? baris.kodeOrder
                        : '${baris.kodeOrder} · '
                              'selesai ${formatWaktuRelatif(baris.selesaiPada!)}',
                    style: teks.bodySmall,
                  ),
                  if (baris.sudahDibayar && baris.dibayarPada != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Dibayarkan ${formatTanggalJam(baris.dibayarPada!)}',
                      style: teks.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spasiKecil),
            // Bayaran yang belum dihitung ditulis dengan kata, bukan Rp 0.
            // Angka nol di kolom ini terbaca sebagai "order ini memang tidak
            // dibayar", dan itu bukan yang sedang terjadi.
            baris.menungguRumus
                ? Text('Menunggu', style: teks.bodySmall)
                : Text(
                    formatRupiah(baris.jumlah),
                    style: teks.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
