import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/galat_api.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/enums.dart';
import '../../domain/models/order.dart';
import '../../domain/service_catalog.dart';
import '../../providers/order_providers.dart';
import '../widgets/pesan_kosong.dart';

/// Kategori filter untuk kotak masuk notifikasi.
enum KategoriNotifikasi { semua, pesanan, info }

/// Layar Kotak Masuk Notifikasi.
///
/// Menggabungkan pembaruan status pesanan aktif pengguna secara real-time
/// dengan pengumuman serta informasi penting seputar operasional UPNVJ Suruh.
class NotifikasiScreen extends ConsumerStatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  ConsumerState<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends ConsumerState<NotifikasiScreen> {
  KategoriNotifikasi _filter = KategoriNotifikasi.semua;

  @override
  Widget build(BuildContext context) {
    final stateOrder = ref.watch(orderKlienProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spasiSedang,
              vertical: AppTheme.spasiKecil,
            ),
            child: Row(
              children: [
                _chipFilter(KategoriNotifikasi.semua, 'Semua'),
                const SizedBox(width: AppTheme.spasiKecil),
                _chipFilter(KategoriNotifikasi.pesanan, 'Pesanan'),
                const SizedBox(width: AppTheme.spasiKecil),
                _chipFilter(KategoriNotifikasi.info, 'Info & Tips'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Daftar Notifikasi
          Expanded(
            child: stateOrder.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (galat, _) => PesanKosong(
                ikon: Icons.wifi_off_outlined,
                judul: 'Notifikasi gagal dimuat',
                keterangan: galat is GalatApi
                    ? galat.pesan
                    : 'Sambungan ke server terputus.',
                labelAksi: 'Coba lagi',
                onAksi: () => ref.invalidate(orderKlienProvider),
              ),
              data: (halaman) => _bangunDaftar(context, halaman.isi),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipFilter(KategoriNotifikasi kategori, String label) {
    final terpilih = _filter == kategori;
    final skema = Theme.of(context).colorScheme;

    return FilterChip(
      selected: terpilih,
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _filter = kategori;
        });
      },
      selectedColor: skema.primaryContainer,
      checkmarkColor: skema.onPrimaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusPil),
      ),
    );
  }

  Widget _bangunDaftar(BuildContext context, List<Order> daftarOrder) {
    final butirNotifikasi = <_ItemNotifikasi>[];

    // Tambahkan notifikasi pembaruan pesanan
    if (_filter == KategoriNotifikasi.semua || _filter == KategoriNotifikasi.pesanan) {
      for (final order in daftarOrder) {
        final item = _buatNotifikasiPesanan(order);
        if (item != null) {
          butirNotifikasi.add(item);
        }
      }
    }

    // Tambahkan notifikasi pengumuman & tips kampus
    if (_filter == KategoriNotifikasi.semua || _filter == KategoriNotifikasi.info) {
      butirNotifikasi.addAll(_pengumumanBawaan());
    }

    if (butirNotifikasi.isEmpty) {
      return const Center(
        child: PesanKosong(
          judul: 'Belum Ada Notifikasi',
          keterangan: 'Pemberitahuan aktivitas pesanan dan informasi terbaru akan muncul di sini.',
          ikon: Icons.notifications_none_outlined,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      itemCount: butirNotifikasi.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spasiKecil),
      itemBuilder: (context, indeks) {
        final notif = butirNotifikasi[indeks];
        return _KartuNotifikasi(item: notif);
      },
    );
  }

  _ItemNotifikasi? _buatNotifikasiPesanan(Order order) {
    final namaLayanan = serviceInfoOf(order.serviceType).nama;

    switch (order.status) {
      case OrderStatus.permintaan:
        return _ItemNotifikasi(
          judul: 'Permintaan Terkirim (${order.kodeOrder})',
          pesan: 'Menunggu penawaran dari runner untuk $namaLayanan.',
          waktu: order.dibuatPada,
          ikon: Icons.handshake_outlined,
          warnaAksen: AppTheme.hijauLencana,
          onTap: (context) => context.push(Rute.detailOrder(order.id)),
        );
      case OrderStatus.menungguPersetujuanKlien:
        return _ItemNotifikasi(
          judul: 'Penawaran Masuk (${order.kodeOrder})',
          pesan: 'Runner telah mengajukan penawaran harga untuk $namaLayanan. Periksa dan setujui penawaran.',
          waktu: order.dibuatPada,
          ikon: Icons.local_offer_outlined,
          warnaAksen: AppTheme.hijauLencana,
          onTap: (context) => context.push(Rute.detailOrder(order.id)),
        );
      case OrderStatus.menungguPembayaran:
        return _ItemNotifikasi(
          judul: 'Selesaikan Pembayaran ${order.kodeOrder}',
          pesan: 'Tagihan untuk layanan $namaLayanan siap dibayar via QRIS.',
          waktu: order.dibuatPada,
          ikon: Icons.payment_outlined,
          warnaAksen: AppTheme.maroonMotor,
          onTap: (context) => context.push(Rute.bayar(order.id)),
        );
      case OrderStatus.mencariRunner:
        return _ItemNotifikasi(
          judul: 'Mencari Runner (${order.kodeOrder})',
          pesan: 'Pembayaran $namaLayanan telah diverifikasi. Pesanan sedang disiarkan ke runner.',
          waktu: order.dibayarPada ?? order.dibuatPada,
          ikon: Icons.search_rounded,
          warnaAksen: AppTheme.hijauLencana,
          onTap: (context) => context.push(Rute.detailOrder(order.id)),
        );
      case OrderStatus.dikerjakan:
        final namaRunner = order.runners.isNotEmpty ? order.runners.first.nama : 'Runner';
        return _ItemNotifikasi(
          judul: 'Pesanan Dikerjakan (${order.kodeOrder})',
          pesan: '$namaRunner sedang menjalankan tugas $namaLayanan Anda.',
          waktu: order.dibuatPada,
          ikon: Icons.directions_bike_rounded,
          warnaAksen: AppTheme.hijauLencana,
          onTap: (context) => context.push(Rute.detailOrder(order.id)),
        );
      case OrderStatus.selesai:
        return _ItemNotifikasi(
          judul: 'Pesanan Selesai (${order.kodeOrder})',
          pesan: 'Tugas $namaLayanan telah selesai. Foto bukti serah terima telah diunggah.',
          waktu: order.selesaiPada ?? order.dibuatPada,
          ikon: Icons.check_circle_outline_rounded,
          warnaAksen: AppTheme.hijauLencana,
          onTap: (context) => context.push(Rute.detailOrder(order.id)),
        );
      case OrderStatus.batal:
        return _ItemNotifikasi(
          judul: 'Pesanan Dibatalkan (${order.kodeOrder})',
          pesan: 'Pesanan $namaLayanan telah dibatalkan.',
          waktu: order.dibuatPada,
          ikon: Icons.cancel_outlined,
          warnaAksen: AppTheme.maroonMotor,
          onTap: (context) => context.push(Rute.detailOrder(order.id)),
        );
    }
  }

  List<_ItemNotifikasi> _pengumumanBawaan() {
    return [
      _ItemNotifikasi(
        judul: 'Selamat Datang di UPNVJ Suruh!',
        pesan: 'Layanan jasa serabutan resmi mahasiswa UPN Veteran Jakarta di bawah naungan Bidang Ekonomi Kreatif.',
        waktu: DateTime(2026, 9, 1),
        ikon: Icons.campaign_outlined,
        warnaAksen: AppTheme.hijauLencana,
        onTap: (context) => _tampilkanDialogInfo(
          context,
          'Selamat Datang di UPNVJ Suruh!',
          'UPNVJ Suruh hadir mempermudah keseharian mahasiswa kampus Pondok Labu & Limo. Manfaatkan fitur Anter Jemput, Jastip Makanan Kantin, Bersih Kos, hingga Pindahan dengan tarif mahasiswa yang transparan.',
        ),
      ),
      _ItemNotifikasi(
        judul: 'Pembayaran Cepat & Otomatis via QRIS',
        pesan: 'Semua pembayaran menggunakan QRIS dinamis Midtrans tanpa perlu konfirmasi manual.',
        waktu: DateTime(2026, 9, 5),
        ikon: Icons.qr_code_scanner_rounded,
        warnaAksen: AppTheme.hijauLencana,
        onTap: (context) => _tampilkanDialogInfo(
          context,
          'Kemudahan QRIS Midtrans',
          'Anda dapat membayar pesanan menggunakan m-banking atau e-wallet apa pun. Sistem webhook Midtrans memverifikasi status pembayaran secara instan.',
        ),
      ),
      _ItemNotifikasi(
        judul: 'Tips Hemat: Jastip Makanan Bareng Teman',
        pesan: 'Titip pesanan makanan kantin atau warung favorit bersama rekan satu kos untuk menghemat waktu dan ongkos.',
        waktu: DateTime(2026, 9, 10),
        ikon: Icons.lightbulb_outline_rounded,
        warnaAksen: AppTheme.hijauLencana,
        onTap: (context) => _tampilkanDialogInfo(
          context,
          'Tips Jastip Mahasiswa',
          'Pesan makanan Jalur A dengan mencantumkan detail menu dan patokan kantin/tempat beli dengan jelas agar runner dapat membelikan tanpa kendala.',
        ),
      ),
    ];
  }

  void _tampilkanDialogInfo(BuildContext context, String judul, String pesan) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(judul),
        content: Text(pesan),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

class _ItemNotifikasi {
  const _ItemNotifikasi({
    required this.judul,
    required this.pesan,
    required this.waktu,
    required this.ikon,
    required this.warnaAksen,
    required this.onTap,
  });

  final String judul;
  final String pesan;
  final DateTime waktu;
  final IconData ikon;
  final Color warnaAksen;
  final void Function(BuildContext context) onTap;
}

class _KartuNotifikasi extends StatelessWidget {
  const _KartuNotifikasi({required this.item});

  final _ItemNotifikasi item;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final teks = Theme.of(context).textTheme;
    final formatTgl = DateFormat('d MMM, HH:mm', 'id_ID');

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: skema.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        side: BorderSide(
          color: skema.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        onTap: () => item.onTap(context),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spasiSedang),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.warnaAksen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.ikon,
                  size: 22,
                  color: item.warnaAksen,
                ),
              ),
              const SizedBox(width: AppTheme.spasiSedang),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.judul,
                            style: teks.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          formatTgl.format(item.waktu),
                          style: teks.bodySmall?.copyWith(
                            color: skema.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.pesan,
                      style: teks.bodySmall?.copyWith(
                        color: skema.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
