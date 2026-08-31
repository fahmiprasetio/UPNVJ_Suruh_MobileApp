import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/service_catalog.dart';
import '../../widgets/rute_order.dart';

/// Satu order yang sedang disiarkan, dilihat dari sisi runner.
///
/// Isinya berbeda dari kartu order milik klien: runner butuh tahu apakah
/// pekerjaan ini layak diambil sekarang, jenis layanan, ke mana, dan berapa
/// nilainya, bukan sejauh mana ordernya sudah berjalan.
///
/// ## Kenapa harganya yang paling besar
///
/// Sebelumnya nilai order ditulis seukuran nama layanan, dan yang paling
/// menonjol di kartu justru nama layanannya. Padahal daftar ini dibaca dengan
/// satu pertanyaan: mana yang kuambil. Nama layanan menjawab "pekerjaan apa",
/// yang penting tapi tidak memutuskan; angkanya yang memutuskan. Sekarang
/// angkanya 20 piksel tebal, sama besar dengan harga di kartu order klien,
/// karena keduanya menjawab pertanyaan yang sama besarnya bagi pembacanya
/// masing-masing (aturan Price Is Loudest di DESIGN.md).
///
/// ## Kenapa harga dan TERIMA tetap satu baris
///
/// Menumpuknya jadi dua baris selebar kartu memang membuat keduanya lebih
/// gagah, tapi kartunya jadi lebih tinggi dan yang muat di satu layar jadi
/// lebih sedikit. Layar ini perlombaan: order yang sama dilihat semua runner
/// pada saat yang sama, dan yang kalah bukan yang salah memilih melainkan yang
/// kalah cepat. Memaksa runner menggulung untuk melihat pilihan keempat adalah
/// biaya yang nyata, sementara gagah tidak membayar apa pun.
class KartuOrderSiaran extends StatelessWidget {
  const KartuOrderSiaran({
    super.key,
    required this.order,
    required this.onTerima,
    this.sedangDiproses = false,
  });

  final Order order;
  final VoidCallback onTerima;

  /// Tombol dikunci selama permintaan TERIMA masih di jalan, supaya satu
  /// ketukan tidak terkirim dua kali.
  final bool sedangDiproses;

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(order.serviceType);
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final adaRute = order.alamatJemput != null || order.alamatTujuan != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiSedang),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(layanan.icon, size: 20, color: skema.onSurfaceVariant),
                const SizedBox(width: AppTheme.spasiKecil),
                Expanded(
                  child: Text(
                    layanan.nama,
                    style: teks.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTheme.spasiKecil),
                // Umur siaran, bukan hiasan. Order yang sudah menunggu setengah
                // jam biasanya menunggu karena ada sebabnya, dan runner berhak
                // tahu itu sebelum menekan tombol yang tidak bisa dibatalkan.
                Text(
                  formatWaktuRelatif(order.dibuatPada),
                  style: teks.bodySmall?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${order.kodeOrder} · ${order.namaKlien}',
              style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
            ),
            if (order.deskripsi != null) ...[
              const SizedBox(height: AppTheme.spasiKecil),
              Text(
                order.deskripsi!,
                style: teks.bodyMedium,
                // Dua baris, lalu dipotong. Permintaan Jalur B bisa sepanjang
                // paragraf, dan satu kartu yang memanjang sendirian mendorong
                // order lain keluar layar di daftar yang sedang diperlombakan.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (adaRute) ...[
              const SizedBox(height: AppTheme.spasiSedang),
              RuteOrder(jemput: order.alamatJemput, tujuan: order.alamatTujuan),
            ],
            if (order.jumlahRunnerDibutuhkan > 1) ...[
              const SizedBox(height: AppTheme.spasiKecil + 2),
              _LencanaKuota(order: order),
            ],
            const SizedBox(height: AppTheme.spasiSedang),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nilai order',
                        style: teks.bodySmall?.copyWith(
                          color: skema.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        formatRupiah(order.harga),
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: skema.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sengaja bukan "pendapatanmu": bagi hasil runner belum
                // diputuskan mitra (rencana capstone bagian 14.7d). Menuliskan
                // angka yang belum disepakati akan lebih menyesatkan daripada
                // tidak menuliskannya.
                const SizedBox(width: AppTheme.spasiSedang),
                _TombolTerima(
                  sedangDiproses: sedangDiproses,
                  onTerima: onTerima,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu-satunya tombol berhuruf besar di aplikasi ini.
///
/// Huruf besarnya dibelanjakan di sini karena tindakan ini yang paling tidak
/// bisa ditarik kembali: menekannya berarti menjanjikan waktu ke orang lain,
/// dan begitu tertekan, ordernya berhenti disiarkan ke runner lain.
///
/// Bayangannya tidak ditulis di sini. Tema sudah memberi setiap [FilledButton]
/// bayangan yang disemir maroonnya sendiri lewat `elevation`, dan menambahkan
/// satu lagi di sini menghasilkan dua bayangan bertumpuk: yang terlihat bukan
/// tombol yang lebih penting, melainkan tombol yang tepinya kotor.
class _TombolTerima extends StatelessWidget {
  const _TombolTerima({required this.sedangDiproses, required this.onTerima});

  final bool sedangDiproses;
  final VoidCallback onTerima;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: FilledButton(
        onPressed: sedangDiproses ? null : onTerima,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: sedangDiproses
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('TERIMA'),
      ),
    );
  }
}

/// Penanda order yang butuh lebih dari satu runner (bagian 5).
///
/// Wadahnya hijau, bukan maroon. Sejak maroon jadi warna sekunder,
/// `secondaryContainer` dan `errorContainer` sama-sama merah muda dan tidak
/// terbedakan pada pil selebar sebelas piksel; merah di sistem ini harus tetap
/// berarti satu hal saja, yaitu ada yang harus dibayar. Berapa orang yang sudah
/// bergabung adalah keadaan, bukan tagihan dan bukan tombol, jadi tempatnya di
/// suara hijau (aturan Status Collision di DESIGN.md).
class _LencanaKuota extends StatelessWidget {
  const _LencanaKuota({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: skema.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusPil),
      ),
      child: Text(
        'Butuh ${order.jumlahRunnerDibutuhkan} orang · '
        '${order.runnerIds.length} sudah gabung',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: skema.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
