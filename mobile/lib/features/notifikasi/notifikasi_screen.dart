import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/galat_api.dart';
import '../../core/providers/order_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/pesan_kosong.dart';
import '../../domain/enums.dart';
import '../../domain/models/order.dart';
import '../../domain/service_catalog.dart';

/// Kategori filter untuk kotak masuk notifikasi.
enum KategoriNotifikasi { semua, pesanan, info }

/// Layar Kotak Masuk Notifikasi.
///
/// Menggunakan desain Aloha Gojek:
/// - AppBar hijau Gojek (#00AA13) tegas dan rapi
/// - Filter chips pill modern dengan aksen hijau
/// - Kartu notifikasi putih bersih berbingkai halus dengan ikon pastel berkategori
/// - Pengalaman visual interaktif, cepat, dan jelas
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
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00AA13),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      body: Column(
        children: [
          // Filter Chips Container
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _chipFilter(KategoriNotifikasi.semua, 'Semua'),
                  const SizedBox(width: 8),
                  _chipFilter(KategoriNotifikasi.pesanan, 'Pesanan'),
                  const SizedBox(width: 8),
                  _chipFilter(KategoriNotifikasi.info, 'Info & Tips'),
                ],
              ),
            ),
          ),
          Container(
            height: 1,
            color: const Color(0xFFEDF2ED),
          ),

          // Daftar Notifikasi
          Expanded(
            child: stateOrder.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00AA13),
                  strokeWidth: 2.5,
                ),
              ),
              error: (galat, _) => PesanKosong(
                ikon: Icons.wifi_off_rounded,
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

    return FilterChip(
      selected: terpilih,
      showCheckmark: terpilih,
      checkmarkColor: const Color(0xFF00880C),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: terpilih ? FontWeight.w700 : FontWeight.w600,
          color: terpilih ? const Color(0xFF00880C) : const Color(0xFF4B5563),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFE8F5E9),
      side: BorderSide(
        color: terpilih ? const Color(0xFF00AA13) : const Color(0xFFE5E7EB),
        width: terpilih ? 1.4 : 1.0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      onSelected: (_) {
        setState(() {
          _filter = kategori;
        });
      },
    );
  }

  Widget _bangunDaftar(BuildContext context, List<Order> daftarOrder) {
    final butirNotifikasi = <_ItemNotifikasi>[];

    // Tambahkan notifikasi pembaruan pesanan
    if (_filter == KategoriNotifikasi.semua ||
        _filter == KategoriNotifikasi.pesanan) {
      for (final order in daftarOrder) {
        final item = _buatNotifikasiPesanan(order);
        if (item != null) {
          butirNotifikasi.add(item);
        }
      }
    }

    // Tambahkan notifikasi pengumuman & tips kampus
    if (_filter == KategoriNotifikasi.semua ||
        _filter == KategoriNotifikasi.info) {
      butirNotifikasi.addAll(_pengumumanBawaan());
    }

    if (butirNotifikasi.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: const PesanKosong(
              judul: 'Belum Ada Notifikasi',
              keterangan:
                  'Pemberitahuan aktivitas pesanan dan informasi terbaru akan muncul di sini.',
              ikon: Icons.notifications_none_rounded,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF00AA13),
      onRefresh: () async => ref.invalidate(orderKlienProvider),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: butirNotifikasi.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, indeks) {
          final notif = butirNotifikasi[indeks];
          return _KartuNotifikasi(item: notif);
        },
      ),
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
          ikon: Icons.handshake_rounded,
          warnaAksen: const Color(0xFF0284C7),
          warnaLatar: const Color(0xFFE0F2FE),
          badgeKategori: 'Permintaan',
          onTap: (context) => context.push(Rute.detailOrder(order.id)),
        );
      case OrderStatus.menungguPersetujuanKlien:
        return _ItemNotifikasi(
          judul: 'Penawaran Masuk (${order.kodeOrder})',
          pesan:
              'Runner telah mengajukan penawaran harga untuk $namaLayanan. Periksa dan setujui penawaran.',
          waktu: order.dibuatPada,
          ikon: Icons.local_offer_rounded,
          warnaAksen: const Color(0xFFD97706),
          warnaLatar: const Color(0xFFFEF3C7),
          badgeKategori: 'Penawaran',
          onTap: (context) => context.push(Rute.detailOrder(order.id)),
        );
      case OrderStatus.menungguPembayaran:
        return _ItemNotifikasi(
          judul: 'Selesaikan Pembayaran ${order.kodeOrder}',
          pesan:
              'Tagihan untuk layanan $namaLayanan siap dibayar melalui Midtrans Snap.',
          waktu: order.dibuatPada,
          ikon: Icons.account_balance_wallet_rounded,
          warnaAksen: const Color(0xFFDC2626),
          warnaLatar: const Color(0xFFFEE2E2),
          badgeKategori: 'Pembayaran',
          onTap: (context) => context.push(Rute.bayar(order.id)),
        );
      case OrderStatus.mencariRunner:
        return _ItemNotifikasi(
          judul: 'Mencari Runner (${order.kodeOrder})',
          pesan:
              'Pembayaran $namaLayanan telah diverifikasi. Pesanan sedang disiarkan ke runner.',
          waktu: order.dibayarPada ?? order.dibuatPada,
          ikon: Icons.search_rounded,
          warnaAksen: const Color(0xFF00AA13),
          warnaLatar: const Color(0xFFE8F5E9),
          badgeKategori: 'Disiarkan',
          onTap: (context) => context.push(Rute.detailOrder(order.id)),
        );
      case OrderStatus.dikerjakan:
        final namaRunner = order.runners.isNotEmpty
            ? order.runners.first.nama
            : 'Runner';
        return _ItemNotifikasi(
          judul: 'Pesanan Dikerjakan (${order.kodeOrder})',
          pesan: '$namaRunner sedang menjalankan tugas $namaLayanan Anda.',
          waktu: order.dibuatPada,
          ikon: Icons.two_wheeler_rounded,
          warnaAksen: const Color(0xFF00880C),
          warnaLatar: const Color(0xFFE8F5E9),
          badgeKategori: 'Dikerjakan',
          onTap: (context) => context.push(Rute.detailOrder(order.id)),
        );
      case OrderStatus.selesai:
        return _ItemNotifikasi(
          judul: 'Pesanan Selesai (${order.kodeOrder})',
          pesan:
              'Tugas $namaLayanan telah selesai. Foto bukti serah terima telah diunggah.',
          waktu: order.selesaiPada ?? order.dibuatPada,
          ikon: Icons.check_circle_rounded,
          warnaAksen: const Color(0xFF00AA13),
          warnaLatar: const Color(0xFFE8F5E9),
          badgeKategori: 'Selesai',
          onTap: (context) => context.push(Rute.detailOrder(order.id)),
        );
      case OrderStatus.batal:
        return _ItemNotifikasi(
          judul: 'Pesanan Dibatalkan (${order.kodeOrder})',
          pesan: 'Pesanan $namaLayanan telah dibatalkan.',
          waktu: order.dibuatPada,
          ikon: Icons.cancel_rounded,
          warnaAksen: const Color(0xFFEF4444),
          warnaLatar: const Color(0xFFFEE2E2),
          badgeKategori: 'Batal',
          onTap: (context) => context.push(Rute.detailOrder(order.id)),
        );
    }
  }

  List<_ItemNotifikasi> _pengumumanBawaan() {
    return [
      _ItemNotifikasi(
        judul: 'Selamat Datang di UPNVJ Suruh!',
        pesan:
            'Layanan jasa serabutan resmi mahasiswa UPN Veteran Jakarta di bawah naungan Bidang Ekonomi Kreatif.',
        waktu: DateTime(2026, 9, 1),
        ikon: Icons.campaign_rounded,
        warnaAksen: const Color(0xFF00AA13),
        warnaLatar: const Color(0xFFE8F5E9),
        badgeKategori: 'Pengumuman',
        onTap: (context) => _tampilkanDialogInfo(
          context,
          'Selamat Datang di UPNVJ Suruh!',
          'UPNVJ Suruh hadir mempermudah keseharian mahasiswa kampus Pondok Labu & Limo. Manfaatkan fitur Anter Jemput, Jastip Makanan Kantin, Bersih Kos, hingga Pindahan dengan tarif mahasiswa yang transparan.',
        ),
      ),
      _ItemNotifikasi(
        judul: 'Pembayaran Aman melalui Midtrans Snap',
        pesan:
            'Semua pembayaran dibuka pada halaman checkout Midtrans Snap tanpa konfirmasi manual.',
        waktu: DateTime(2026, 9, 5),
        ikon: Icons.verified_user_rounded,
        warnaAksen: const Color(0xFF0284C7),
        warnaLatar: const Color(0xFFE0F2FE),
        badgeKategori: 'Sistem',
        onTap: (context) => _tampilkanDialogInfo(
          context,
          'Kemudahan Midtrans Snap',
          'Pilih metode pembayaran yang tersedia pada halaman Midtrans Snap. Sistem webhook Midtrans memverifikasi status pembayaran secara otomatis.',
        ),
      ),
      _ItemNotifikasi(
        judul: 'Tips Hemat: Jastip Makanan Bareng Teman',
        pesan:
            'Titip pesanan makanan kantin atau warung favorit bersama rekan satu kos untuk menghemat waktu dan ongkos.',
        waktu: DateTime(2026, 9, 10),
        ikon: Icons.lightbulb_rounded,
        warnaAksen: const Color(0xFFF59E0B),
        warnaLatar: const Color(0xFFFEF3C7),
        badgeKategori: 'Tips',
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: Color(0xFF00AA13),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                judul,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2124),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          pesan,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF4B5563),
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00AA13),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Tutup',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
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
    required this.warnaLatar,
    this.badgeKategori,
    required this.onTap,
  });

  final String judul;
  final String pesan;
  final DateTime waktu;
  final IconData ikon;
  final Color warnaAksen;
  final Color warnaLatar;
  final String? badgeKategori;
  final void Function(BuildContext context) onTap;
}

class _KartuNotifikasi extends StatelessWidget {
  const _KartuNotifikasi({required this.item});

  final _ItemNotifikasi item;

  @override
  Widget build(BuildContext context) {
    final formatTgl = DateFormat('d MMM, HH:mm', 'id_ID');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEDF2ED),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => item.onTap(context),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ikon kategori / status dengan container bulat pastel
                Container(
                  height: 44,
                  width: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.warnaLatar,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.ikon, size: 22, color: item.warnaAksen),
                ),
                const SizedBox(width: 14),
                // Konten teks judul, pesan, dan waktu
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.judul,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E2124),
                                letterSpacing: -0.2,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatTgl.format(item.waktu),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.pesan,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                          height: 1.45,
                        ),
                      ),
                      if (item.badgeKategori != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: item.warnaLatar,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.badgeKategori!,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: item.warnaAksen,
                                ),
                              ),
                            ),
                            const Row(
                              children: [
                                Text(
                                  'Lihat',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF00AA13),
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 15,
                                  color: Color(0xFF00AA13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
