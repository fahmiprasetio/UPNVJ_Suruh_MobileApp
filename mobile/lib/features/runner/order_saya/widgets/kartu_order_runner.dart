import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/service_catalog.dart';
import '../../widgets/rute_order.dart';

/// Satu order yang dipegang runner.
///
/// Bentuknya berubah menurut keadaan order: yang sedang dikerjakan menawarkan
/// tindakan, yang sudah selesai memperlihatkan bukti yang tertinggal. Kartu
/// ini tidak pernah kosong tindakan sekaligus kosong keterangan.
///
/// ## Kenapa kartunya boleh tinggi, tidak seperti kartu siaran
///
/// Kartu siaran di Order Masuk sengaja dipadatkan supaya lebih banyak yang muat
/// di satu layar, karena di sana runner sedang berlomba dan setiap gulungan
/// adalah waktu yang hilang. Di sini tidak ada lomba: ordernya sudah miliknya,
/// jumlahnya jarang lebih dari beberapa, dan yang ia butuhkan bukan memilih
/// melainkan mengerjakan. Karena itu alamat ditulis lengkap, harga diberi baris
/// sendiri, dan tombolnya selebar kartu.
///
/// ## Kenapa alamat jemputnya ikut, padahal dulu tidak
///
/// Sebelumnya kartu ini hanya menampilkan alamat tujuan. Untuk order antar
/// jemput itu berarti begitu runner menekan TERIMA, alamat jemput yang tadi
/// terbaca jelas di kartu siaran menghilang dari aplikasinya, tepat pada saat
/// ia mulai membutuhkannya. Rutenya sekarang digambar dengan widget yang sama
/// dengan kartu siaran, jadi yang ia lihat sebelum dan sesudah menerima
/// benar-benar bentuk yang sama.
///
/// ## Kenapa tidak ada lencana status
///
/// Daftarnya sudah berjudul "Sedang dikerjakan" dan "Sudah selesai", dan setiap
/// kartu selalu berada di bawah salah satunya. Pil status di sini akan
/// mengulang kata yang sudah tertulis dua sentimeter di atasnya.
class KartuOrderRunner extends StatelessWidget {
  const KartuOrderRunner({
    super.key,
    required this.order,
    this.onSelesaikan,
    this.onLepas,
    this.onChat,
  });

  final Order order;

  /// `null` untuk order yang sudah selesai, tidak ada lagi yang bisa
  /// dilakukan runner terhadapnya.
  final VoidCallback? onSelesaikan;

  /// Runner mundur dari order ini. Hanya ada selama ordernya masih berjalan;
  /// yang sudah selesai tidak bisa dilepas lagi.
  final VoidCallback? onLepas;

  /// Pintu ke ruang chat order. Tetap tersedia untuk order yang sudah selesai
  /// karena percakapannya masih boleh dibaca, cuma tidak bisa dibalas.
  final VoidCallback? onChat;

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
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${order.kodeOrder} · ${order.namaKlien}',
              style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
            ),
            if (order.deskripsi != null) ...[
              const SizedBox(height: AppTheme.spasiKecil),
              Text(order.deskripsi!, style: teks.bodyMedium),
            ],
            if (adaRute) ...[
              const SizedBox(height: AppTheme.spasiSedang),
              RuteOrder(jemput: order.alamatJemput, tujuan: order.alamatTujuan),
            ],
            const SizedBox(height: AppTheme.spasiSedang),
            Text(
              formatRupiah(order.harga),
              style: TextStyle(
                fontSize: 20,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: skema.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            if (onSelesaikan != null)
              FilledButton.icon(
                onPressed: onSelesaikan,
                icon: const Icon(Icons.task_alt_outlined),
                label: const Text('Selesaikan Order'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              )
            else
              _RingkasanPenyelesaian(order: order),
            if (onChat != null || onLepas != null) ...[
              const SizedBox(height: 4),
              // Tombol teks, bukan tombol bergaris. Bergaris membuatnya
              // seukuran dan sekeras tombol maroon di atasnya, dan kartu dengan
              // dua tombol selebar penuh yang sama kerasnya tidak punya tindakan
              // utama lagi, cuma dua pilihan yang sama-sama menuntut. Chat
              // memang jalan sampingan; bentuknya sekarang mengaku begitu.
              //
              // "Lepas order" berdiri di ujung seberang, jauh dari chat dan jauh
              // dari tombol selesai, dan tanpa ikon. Ia jalan keluar yang memang
              // harus ada, tapi bukan sesuatu yang pantas ditawarkan sejajar
              // dengan menyelesaikan pekerjaan; yang mencarinya akan menemukannya,
              // yang tidak mencarinya tidak akan tersenggol.
              Row(
                children: [
                  if (onChat != null)
                    TextButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.forum_outlined, size: 18),
                      label: Text(
                        order.jumlahPesan == 0
                            ? 'Chat Klien'
                            : 'Chat Klien (${order.jumlahPesan})',
                      ),
                      style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                    ),
                  const Spacer(),
                  if (onLepas != null)
                    TextButton(
                      onPressed: onLepas,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: skema.onSurfaceVariant,
                      ),
                      child: const Text('Lepas order'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Jejak yang tertinggal setelah order ditutup: kapan, bukti apa, pesan apa.
class _RingkasanPenyelesaian extends StatelessWidget {
  const _RingkasanPenyelesaian({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: skema.primary),
            const SizedBox(width: AppTheme.spasiKecil),
            Expanded(
              child: Text(
                order.selesaiPada == null
                    ? 'Selesai'
                    : 'Selesai ${formatTanggalJam(order.selesaiPada!)}',
                style: teks.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (order.fotoBuktiUrl != null) ...[
          const SizedBox(height: 4),
          Text(
            'Foto bukti tersimpan',
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
        ],
        if (order.catatanSerahTerima != null) ...[
          const SizedBox(height: 4),
          Text(
            'Catatan: ${order.catatanSerahTerima!}',
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
