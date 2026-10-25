import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/format/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/pendapatan.dart';
import '../../../domain/service_catalog.dart';
import '../../../core/providers/repository_providers.dart';
import '../../peran/tombol_ganti_mode.dart';
import '../../../core/widgets/pesan_kosong.dart';
import '../../../core/widgets/tombol_profil.dart';

/// Pendapatan runner dengan bahasa visual Aloha Gojek yang modern, bersih,
/// dan hemat ruang.
class PendapatanScreen extends ConsumerWidget {
  const PendapatanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendapatan = ref.watch(pendapatanProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8EA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF00AA13),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pendapatan Saya',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Dompet & Riwayat Pencairan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: const [TombolGantiMode(), TombolProfil()],
      ),
      body: SafeArea(
        child: pendapatan.when(
          skipLoadingOnReload: true,
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00AA13),
              strokeWidth: 3,
            ),
          ),
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
            color: const Color(0xFF00AA13),
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
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _KartuRingkasan(pendapatan: pendapatan),
        const SizedBox(height: 20),
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
    final warnaAksen = judul.contains('Belum')
        ? const Color(0xFF00AA13)
        : const Color(0xFF6B7280);

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: warnaAksen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$judul (${baris.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
      for (final b in baris)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _KartuBaris(baris: b),
        ),
      const SizedBox(height: 12),
    ];
  }
}

/// Hero card dompet runner bertema Aloha Gojek
class _KartuRingkasan extends StatelessWidget {
  const _KartuRingkasan({required this.pendapatan});

  final Pendapatan pendapatan;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pill Header Dompet
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EA),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'DOMPET RUNNER',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00AA13),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.shield_outlined,
                  size: 15,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Terjamin Resmi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Metrik Utama: Belum dibayarkan
            const Text(
              'Belum dibayarkan',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatRupiah(pendapatan.totalBelumDibayar),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),

            // Baris: Sudah diterima
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F8EA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: Color(0xFF00AA13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sudah diterima: '
                    '${formatRupiah(pendapatan.totalSudahDibayar)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),

            // Catatan Menunggu Rumus (Jika Ada)
            if (pendapatan.menungguRumus > 0) ...[
              const SizedBox(height: 12),
              _CatatanMenungguRumus(jumlah: pendapatan.menungguRumus),
            ],
          ],
        ),
      ),
    );
  }
}

/// Catatan menunggu rumus yang proporsional dan tidak memakan banyak tempat
class _CatatanMenungguRumus extends StatelessWidget {
  const _CatatanMenungguRumus({required this.jumlah});

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            size: 15,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$jumlah order sudah selesai tapi bayarannya belum dihitung. '
              'Admin belum menetapkan bagi hasilnya.',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF92400E),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu satu baris pencairan pendapatan
class _KartuBaris extends StatelessWidget {
  const _KartuBaris({required this.baris});

  final BarisPendapatan baris;

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(baris.layanan);
    final warna = _warnaLayanan(baris.layanan);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: warna.latar,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(layanan.icon, size: 18, color: warna.aksen),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    layanan.nama,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    baris.selesaiPada == null
                        ? baris.kodeOrder
                        : '${baris.kodeOrder} · '
                            'selesai ${formatWaktuRelatif(baris.selesaiPada!)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (baris.sudahDibayar && baris.dibayarPada != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Dibayarkan ${formatTanggalJam(baris.dibayarPada!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF00AA13),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Bayaran yang belum dihitung ditulis 'Menunggu', bukan Rp 0.
            if (baris.menungguRumus)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Menunggu',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD97706),
                  ),
                ),
              )
            else
              Text(
                formatRupiah(baris.jumlah),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static ({Color latar, Color aksen}) _warnaLayanan(ServiceType type) {
    switch (type) {
      case ServiceType.anterJemput:
        return (latar: const Color(0xFFE8F8EA), aksen: const Color(0xFF00AA13));
      case ServiceType.jastipMakanan:
        return (latar: const Color(0xFFFFF7ED), aksen: const Color(0xFFEA580C));
      case ServiceType.jastipBarang:
        return (latar: const Color(0xFFEFF6FF), aksen: const Color(0xFF2563EB));
      case ServiceType.bersihKamarMandi:
      case ServiceType.bersihKos:
        return (latar: const Color(0xFFF0FDF4), aksen: const Color(0xFF059669));
      case ServiceType.bantuPindahKos:
        return (latar: const Color(0xFFFAF5FF), aksen: const Color(0xFF9333EA));
      case ServiceType.permintaanLain:
        return (latar: const Color(0xFFFDF2F8), aksen: const Color(0xFFDB2777));
    }
  }
}
