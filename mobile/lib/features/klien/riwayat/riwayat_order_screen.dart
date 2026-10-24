import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/models/order.dart';
import '../../../domain/service_catalog.dart';
import '../../../core/providers/order_providers.dart';
import '../../../core/providers/ukuran_daftar.dart';
import '../../../core/widgets/pesan_kosong.dart';
import '../../../core/widgets/rangka_daftar_order.dart';
import '../../../core/widgets/tombol_muat_lagi.dart';
import '../buka_form_order.dart';
import '../widgets/kartu_order_ringkas.dart';

/// Filter tab visual pada antarmuka riwayat order Aloha
enum _FilterPesananTab {
  semua('Semua'),
  berjalan('Sedang Berjalan'),
  selesai('Sudah Selesai');

  const _FilterPesananTab(this.label);
  final String label;
}

/// Order ini cocok dengan kata kunci pencarian atau tidak.
///
/// Dicocokkan ke kode order, nama layanan, dan catatan -- tiga hal yang sudah
/// tertulis di kartu ringkasnya sendiri (lihat [KartuOrderRingkas]), supaya
/// apa yang bisa dicari selalu sama dengan apa yang terlihat, tidak lebih
/// tidak kurang. Fungsi murni, terpisah dari widgetnya, supaya pencocokannya
/// bisa diuji tanpa merender apa pun.
bool cocokPencarianOrder(Order order, String kueri) {
  final bersih = kueri.trim().toLowerCase();
  if (bersih.isEmpty) return true;

  return order.kodeOrder.toLowerCase().contains(bersih) ||
      serviceInfoOf(order.serviceType).nama.toLowerCase().contains(bersih) ||
      (order.deskripsi?.toLowerCase().contains(bersih) ?? false);
}

/// Daftar order milik klien dengan estetika modern Gojek Aloha.
class RiwayatOrderScreen extends ConsumerStatefulWidget {
  const RiwayatOrderScreen({super.key, this.onMintaBeranda});

  final VoidCallback? onMintaBeranda;

  @override
  ConsumerState<RiwayatOrderScreen> createState() => _RiwayatOrderScreenState();
}

class _RiwayatOrderScreenState extends ConsumerState<RiwayatOrderScreen> {
  final _pencarianController = TextEditingController();
  _FilterPesananTab _tabAktif = _FilterPesananTab.semua;

  @override
  void dispose() {
    _pencarianController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderKlienProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F8EA),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF00AA13),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pesanan',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Riwayat & aktivitas pesanan',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF374151)),
            tooltip: 'Segarkan',
            onPressed: () => ref.invalidate(orderKlienProvider),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: orders.when(
        skipLoadingOnReload: true,
        loading: () => const RangkaDaftarOrder(),
        error: (galat, _) => PesanKosong(
          ikon: Icons.wifi_off_outlined,
          judul: 'Order gagal dimuat',
          keterangan: galat is GalatApi
              ? galat.pesan
              : 'Sambungan ke server terputus.',
          labelAksi: 'Coba lagi',
          onAksi: () => ref.invalidate(orderKlienProvider),
        ),
        data: (halaman) {
          final semua = halaman.isi;
          if (semua.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F8EA),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.receipt_long_outlined,
                          size: 44,
                          color: Color(0xFF00AA13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Belum ada pesanan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pesanan yang kamu buat muncul di sini, lengkap dengan '
                      'status perjalanan dan rincian pembayarannya.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                    if (widget.onMintaBeranda != null) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: widget.onMintaBeranda,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00AA13),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Mulai memesan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          final kueri = _pencarianController.text;
          final tersaringKueri = kueri.trim().isEmpty
              ? semua
              : semua.where((o) => cocokPencarianOrder(o, kueri)).toList();

          final semuaBerjalan = tersaringKueri
              .where((o) => o.status.isAktif)
              .toList();
          final semuaSelesai = tersaringKueri
              .where((o) => !o.status.isAktif)
              .toList();

          final tampilkanBerjalan =
              _tabAktif == _FilterPesananTab.semua ||
              _tabAktif == _FilterPesananTab.berjalan;
          final tampilkanSelesai =
              _tabAktif == _FilterPesananTab.semua ||
              _tabAktif == _FilterPesananTab.selesai;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              // 1. KOLOM PENCARIAN ALOHA
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _pencarianController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Cari kode, layanan, atau catatan',
                    hintStyle: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF00AA13),
                      size: 22,
                    ),
                    suffixIcon: kueri.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFF6B7280),
                              size: 18,
                            ),
                            onPressed: () =>
                                setState(_pencarianController.clear),
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. SEGMENTED FILTER CHIPS ALOHA
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ChipTabAloha(
                      label: 'Semua',
                      jumlah: tersaringKueri.length,
                      terpilih: _tabAktif == _FilterPesananTab.semua,
                      onTap: () =>
                          setState(() => _tabAktif = _FilterPesananTab.semua),
                    ),
                    const SizedBox(width: 8),
                    _ChipTabAloha(
                      label: 'Sedang Berjalan',
                      jumlah: semuaBerjalan.length,
                      terpilih: _tabAktif == _FilterPesananTab.berjalan,
                      adaTitikAktif: semuaBerjalan.isNotEmpty,
                      onTap: () => setState(
                        () => _tabAktif = _FilterPesananTab.berjalan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ChipTabAloha(
                      label: 'Sudah Selesai',
                      jumlah: semuaSelesai.length,
                      terpilih: _tabAktif == _FilterPesananTab.selesai,
                      onTap: () =>
                          setState(() => _tabAktif = _FilterPesananTab.selesai),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (tersaringKueri.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Tidak ada order yang cocok dengan "${kueri.trim()}".',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              else ...[
                if (tampilkanBerjalan && semuaBerjalan.isNotEmpty)
                  ..._bagian(
                    context,
                    'Sedang berjalan',
                    semuaBerjalan,
                    pertama: true,
                    aktif: true,
                  ),
                if (tampilkanSelesai && semuaSelesai.isNotEmpty)
                  ..._bagian(
                    context,
                    'Sudah selesai',
                    semuaSelesai,
                    pertama: !tampilkanBerjalan || semuaBerjalan.isEmpty,
                    aktif: false,
                  ),
              ],

              const SizedBox(height: 8),
              TombolMuatLagi(
                halaman: halaman,
                ukuranProvider: ukuranOrderKlienProvider,
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _bagian(
    BuildContext context,
    String judul,
    List<Order> orders, {
    required bool pertama,
    required bool aktif,
  }) {
    return [
      if (!pertama) const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: aktif
                    ? const Color(0xFF00AA13)
                    : const Color(0xFF9CA3AF),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$judul (${orders.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
      for (final order in orders)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: KartuOrderRingkas(
            order: order,
            onTap: () => context.push(Rute.detailOrder(order.id)),
            onPesanLagi:
                order.status.isAktif || !adaFormOrder(order.serviceType)
                ? null
                : () =>
                      bukaFormOrder(context, order.serviceType, contoh: order),
          ),
        ),
    ];
  }
}

/// Chip tombol filter tab Aloha
class _ChipTabAloha extends StatelessWidget {
  const _ChipTabAloha({
    required this.label,
    required this.jumlah,
    required this.terpilih,
    required this.onTap,
    this.adaTitikAktif = false,
  });

  final String label;
  final int jumlah;
  final bool terpilih;
  final VoidCallback onTap;
  final bool adaTitikAktif;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: terpilih ? const Color(0xFF00AA13) : Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: terpilih
                  ? const Color(0xFF00AA13)
                  : const Color(0xFFE5E7EB),
              width: 1,
            ),
            boxShadow: terpilih
                ? [
                    BoxShadow(
                      color: const Color(0xFF00AA13).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (adaTitikAktif) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: terpilih ? Colors.white : const Color(0xFF00AA13),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: terpilih ? FontWeight.w800 : FontWeight.w600,
                  color: terpilih ? Colors.white : const Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: terpilih
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$jumlah',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: terpilih ? Colors.white : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
