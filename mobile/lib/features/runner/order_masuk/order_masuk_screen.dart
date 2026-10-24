import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/api/idempotency_key.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/runner_providers.dart';
import '../../../core/providers/ukuran_daftar.dart';
import '../../../core/widgets/rangka_daftar_order.dart';
import '../../../core/widgets/tombol_muat_lagi.dart';
import '../../../core/widgets/tombol_profil.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../peran/tombol_ganti_mode.dart';
import 'widgets/kartu_order_siaran.dart';

/// Layar utama runner: daftar order yang sudah dibayar dan sedang disiarkan.
///
/// Mengusung antarmuka modern ala Gojek Aloha:
/// - Bilah atas hijau Gojek dengan indikator status online & aktif runner
/// - Bilah filter kategori layanan interaktif (Semua, Anter Jemput, Jastip, dll.)
/// - Ticker siaran langsung dengan tombol segarkan instan
/// - Kartu order siaran visual dengan rute pin jelas dan tombol "TERIMA" Gojek
class OrderMasukScreen extends ConsumerStatefulWidget {
  const OrderMasukScreen({super.key});

  @override
  ConsumerState<OrderMasukScreen> createState() => _OrderMasukScreenState();
}

class _OrderMasukScreenState extends ConsumerState<OrderMasukScreen> {
  /// Filter kategori aktif yang dipilih runner (null = Semua)
  ServiceType? _kategoriDipilih;

  /// Order yang tombolnya sedang menunggu jawaban agar tidak tertekan ganda.
  final Set<String> _sedangDiproses = {};
  final Map<String, String> _keyTerima = {};

  @override
  Widget build(BuildContext context) {
    final tersiar = ref.watch(orderTersiarProvider);

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
                  Icons.two_wheeler_rounded,
                  color: Color(0xFF00AA13),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Order Masuk',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.2,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00AA13),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Siap Terima Order',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00880C),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: const [TombolGantiMode(), TombolProfil(), SizedBox(width: 6)],
      ),
      body: SafeArea(
        child: tersiar.when(
          skipLoadingOnReload: true,
          loading: () => const RangkaDaftarOrder(
            denganJudulBagian: false,
            denganTombol: true,
          ),
          error: (galat, _) => _PesanGalatAloha(
            pesan: galat is GalatApi
                ? galat.pesan
                : 'Sambungan ke server terputus.',
            onCobaLagi: () => ref.invalidate(orderTersiarProvider),
          ),
          data: (halaman) {
            final semuaOrders = halaman.isi;

            // Terapkan filter kategori jika dipilih
            final orders = _kategoriDipilih == null
                ? semuaOrders
                : semuaOrders
                      .where((o) => o.serviceType == _kategoriDipilih)
                      .toList();

            return Column(
              children: [
                // 1. BILAH CHIP FILTER KATEGORI LAYANAN
                _BilahFilterKategori(
                  kategoriDipilih: _kategoriDipilih,
                  totalSemua: semuaOrders.length,
                  onPilih: (kategori) {
                    setState(() => _kategoriDipilih = kategori);
                  },
                ),

                // 2. TICKER INFORMASI & REFRESH CEPAT
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF7ED),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          semuaOrders.isEmpty
                              ? 'Radar aktif mencari siaran order baru...'
                              : 'Tersedia ${orders.length} order menunggu runner',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => ref.invalidate(orderTersiarProvider),
                        borderRadius: BorderRadius.circular(100),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: Color(0xFF00880C),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Segarkan',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF00880C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. DAFTAR KARTU ORDER ATAU EMPTY STATE
                Expanded(
                  child: orders.isEmpty
                      ? _PesanKosongAloha(
                          adaFilter: _kategoriDipilih != null,
                          onResetFilter: () =>
                              setState(() => _kategoriDipilih = null),
                          onCobaLagi: () =>
                              ref.invalidate(orderTersiarProvider),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          itemCount: orders.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, indeks) {
                            if (indeks == orders.length) {
                              return TombolMuatLagi(
                                halaman: halaman,
                                ukuranProvider: ukuranOrderTersiarProvider,
                              );
                            }

                            final order = orders[indeks];
                            return KartuOrderSiaran(
                              order: order,
                              sedangDiproses: _sedangDiproses.contains(
                                order.id,
                              ),
                              onTerima: () => _terima(order),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _terima(Order order) async {
    final user = ref.read(userAktifProvider).value;
    if (user == null) return;

    setState(() => _sedangDiproses.add(order.id));
    final key = _keyTerima.putIfAbsent(order.id, buatIdempotencyKey);

    final bool dapat;
    try {
      dapat = await ref
          .read(orderRepositoryProvider)
          .terimaOrder(orderId: order.id, idempotencyKey: key);
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangDiproses.remove(order.id));
      _kabari(
        galat is GalatApi
            ? 'Order ${order.kodeOrder} gagal diambil: ${galat.pesan}'
            : 'Order ${order.kodeOrder} gagal diambil. Terjadi kendala sambungan atau server.',
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _sedangDiproses.remove(order.id);
      _keyTerima.remove(order.id);
    });

    _kabari(
      dapat
          ? '🎉 Order ${order.kodeOrder} berhasil kamu ambil! Segera kerjakan.'
          : '⚠️ Order ${order.kodeOrder} keburu diambil oleh runner lain.',
    );
  }

  void _kabari(String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            pesan,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF1F2937),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}

/// Bilah filter kategori layanan horizontal
class _BilahFilterKategori extends StatelessWidget {
  const _BilahFilterKategori({
    required this.kategoriDipilih,
    required this.totalSemua,
    required this.onPilih,
  });

  final ServiceType? kategoriDipilih;
  final int totalSemua;
  final ValueChanged<ServiceType?> onPilih;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _ItemFilter(
              label: 'Semua',
              jumlah: totalSemua,
              terpilih: kategoriDipilih == null,
              onTap: () => onPilih(null),
            ),
            const SizedBox(width: 8),
            _ItemFilter(
              label: 'Anter Jemput',
              icon: Icons.two_wheeler_rounded,
              terpilih: kategoriDipilih == ServiceType.anterJemput,
              onTap: () => onPilih(ServiceType.anterJemput),
            ),
            const SizedBox(width: 8),
            _ItemFilter(
              label: 'Jastip Makanan',
              icon: Icons.lunch_dining_rounded,
              terpilih: kategoriDipilih == ServiceType.jastipMakanan,
              onTap: () => onPilih(ServiceType.jastipMakanan),
            ),
            const SizedBox(width: 8),
            _ItemFilter(
              label: 'Jastip Barang',
              icon: Icons.shopping_bag_outlined,
              terpilih: kategoriDipilih == ServiceType.jastipBarang,
              onTap: () => onPilih(ServiceType.jastipBarang),
            ),
            const SizedBox(width: 8),
            _ItemFilter(
              label: 'Kamar Mandi',
              icon: Icons.bathtub_outlined,
              terpilih: kategoriDipilih == ServiceType.bersihKamarMandi,
              onTap: () => onPilih(ServiceType.bersihKamarMandi),
            ),
            const SizedBox(width: 8),
            _ItemFilter(
              label: 'Bersih Kos',
              icon: Icons.cleaning_services_rounded,
              terpilih: kategoriDipilih == ServiceType.bersihKos,
              onTap: () => onPilih(ServiceType.bersihKos),
            ),
            const SizedBox(width: 8),
            _ItemFilter(
              label: 'Pindah Kos',
              icon: Icons.local_shipping_outlined,
              terpilih: kategoriDipilih == ServiceType.bantuPindahKos,
              onTap: () => onPilih(ServiceType.bantuPindahKos),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemFilter extends StatelessWidget {
  const _ItemFilter({
    required this.label,
    this.icon,
    this.jumlah,
    required this.terpilih,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final int? jumlah;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: terpilih ? const Color(0xFFE8F8EA) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: terpilih ? const Color(0xFF00AA13) : const Color(0xFFE5E7EB),
            width: terpilih ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: terpilih
                    ? const Color(0xFF00880C)
                    : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: terpilih ? FontWeight.w800 : FontWeight.w600,
                color: terpilih
                    ? const Color(0xFF00880C)
                    : const Color(0xFF374151),
              ),
            ),
            if (jumlah != null && jumlah! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: terpilih
                      ? const Color(0xFF00AA13)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$jumlah',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: terpilih ? Colors.white : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tampilan Empty State Radar Gojek Aloha saat tidak ada order masuk
class _PesanKosongAloha extends StatelessWidget {
  const _PesanKosongAloha({
    required this.adaFilter,
    required this.onResetFilter,
    required this.onCobaLagi,
  });

  final bool adaFilter;
  final VoidCallback onResetFilter;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ilustrasi Radar Konsentris Aloha
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8EA).withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F8EA),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.radar_rounded,
                      size: 34,
                      color: Color(0xFF00AA13),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              adaFilter
                  ? 'Tidak Ada Order di Kategori Ini'
                  : 'Belum Ada Order Masuk',
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              adaFilter
                  ? 'Coba pilih kategori lain atau tampilkan seluruh order masuk.'
                  : 'Order dari mahasiswa UPNVJ yang sudah dibayar akan disiarkan ke sini secara realtime. Tetap aktif dan standby!',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (adaFilter)
              OutlinedButton.icon(
                onPressed: onResetFilter,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00880C),
                  side: const BorderSide(color: Color(0xFF00AA13)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text(
                  'Tampilkan Semua Kategori',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: onCobaLagi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00AA13),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Segarkan Radar',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tampilan galat modern saat koneksi gagal
class _PesanGalatAloha extends StatelessWidget {
  const _PesanGalatAloha({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 32,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Order Gagal Dimuat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              pesan,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onCobaLagi,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00AA13),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 11,
                ),
              ),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
