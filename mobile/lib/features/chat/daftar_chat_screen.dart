import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/galat_api.dart';
import '../../core/router/app_router.dart';
import '../../core/format/formatters.dart';
import '../../domain/models/order.dart';
import '../../domain/service_catalog.dart';
import '../../core/providers/order_providers.dart';
import '../../core/providers/ukuran_daftar.dart';
import '../../core/widgets/pesan_kosong.dart';
import '../../core/widgets/rangka_daftar_order.dart';
import '../../core/widgets/tombol_muat_lagi.dart';
import '../klien/widgets/lencana_status.dart';

/// Tab filter pada layar daftar chat Aloha
enum _FilterChatTab {
  semua('Semua'),
  belumDibaca('Belum Dibaca'),
  aktif('Pesanan Berjalan');

  const _FilterChatTab(this.label);
  final String label;
}

/// Daftar percakapan klien dengan estetika modern Gojek Aloha.
///
/// Setiap percakapan terikat pada order tertentu, menampilkan avatar layanan tematik,
/// status pengerjaan, kode order, timestamp relatif, dan lencana pesan baru.
class DaftarChatScreen extends ConsumerStatefulWidget {
  const DaftarChatScreen({super.key});

  @override
  ConsumerState<DaftarChatScreen> createState() => _DaftarChatScreenState();
}

class _DaftarChatScreenState extends ConsumerState<DaftarChatScreen> {
  final _pencarianController = TextEditingController();
  _FilterChatTab _tabAktif = _FilterChatTab.semua;

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
                  Icons.chat_bubble_rounded,
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
                  'Chat',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Percakapan aktif pesanan',
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
          judul: 'Chat gagal dimuat',
          keterangan: galat is GalatApi
              ? galat.pesan
              : 'Sambungan ke server terputus.',
          labelAksi: 'Coba lagi',
          onAksi: () => ref.invalidate(orderKlienProvider),
        ),
        data: (halaman) {
          final semuaBerpercakapan =
              halaman.isi.where((o) => o.jumlahPesan > 0).toList()
                ..sort((a, b) {
                  final belumDibacaA = a.jumlahPesanBelumDibaca > 0;
                  final belumDibacaB = b.jumlahPesanBelumDibaca > 0;
                  if (belumDibacaA != belumDibacaB) {
                    return belumDibacaA ? -1 : 1;
                  }
                  return b.dibuatPada.compareTo(a.dibuatPada);
                });

          if (semuaBerpercakapan.isEmpty) {
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
                          Icons.forum_outlined,
                          size: 44,
                          color: Color(0xFF00AA13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Belum ada percakapan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chat yang menempel pada orderanmu muncul di sini begitu '
                      'ada komunikasi dengan runner atau admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final kueri = _pencarianController.text.trim().toLowerCase();
          final tersaringKueri = kueri.isEmpty
              ? semuaBerpercakapan
              : semuaBerpercakapan.where((o) {
                  return o.kodeOrder.toLowerCase().contains(kueri) ||
                      serviceInfoOf(
                        o.serviceType,
                      ).nama.toLowerCase().contains(kueri) ||
                      (o.deskripsi?.toLowerCase().contains(kueri) ?? false);
                }).toList();

          final tersaringTab = switch (_tabAktif) {
            _FilterChatTab.semua => tersaringKueri,
            _FilterChatTab.belumDibaca =>
              tersaringKueri
                  .where((o) => o.jumlahPesanBelumDibaca > 0)
                  .toList(),
            _FilterChatTab.aktif =>
              tersaringKueri.where((o) => o.status.isAktif).toList(),
          };

          final jumlahBelumDibacaTotal = semuaBerpercakapan
              .where((o) => o.jumlahPesanBelumDibaca > 0)
              .length;
          final jumlahAktifTotal = semuaBerpercakapan
              .where((o) => o.status.isAktif)
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              // 1. KOLOM PENCARIAN CHAT ALOHA
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
                    hintText: 'Cari obrolan, kode, atau layanan...',
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

              const SizedBox(height: 10),

              // 2. BANNER INFORMASI KEAMANAN ALOHA
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: Color(0xFF00AA13),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chat resmi UPNVJ Suruh menempel otomatis pada setiap order.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 3. SEGMENTED FILTER TABS ALOHA
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ChipTabChatAloha(
                      label: 'Semua',
                      jumlah: semuaBerpercakapan.length,
                      terpilih: _tabAktif == _FilterChatTab.semua,
                      onTap: () =>
                          setState(() => _tabAktif = _FilterChatTab.semua),
                    ),
                    const SizedBox(width: 8),
                    _ChipTabChatAloha(
                      label: 'Belum Dibaca',
                      jumlah: jumlahBelumDibacaTotal,
                      terpilih: _tabAktif == _FilterChatTab.belumDibaca,
                      adaTitikAktif: jumlahBelumDibacaTotal > 0,
                      onTap: () => setState(
                        () => _tabAktif = _FilterChatTab.belumDibaca,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ChipTabChatAloha(
                      label: 'Pesanan Berjalan',
                      jumlah: jumlahAktifTotal,
                      terpilih: _tabAktif == _FilterChatTab.aktif,
                      onTap: () =>
                          setState(() => _tabAktif = _FilterChatTab.aktif),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (tersaringTab.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      kueri.isNotEmpty
                          ? 'Tidak ada obrolan yang cocok dengan "$kueri".'
                          : 'Tidak ada obrolan di kategori ini.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              else
                for (final order in tersaringTab)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BarisChat(order: order),
                  ),

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
}

/// Baris percakapan order dalam wadah kartu Aloha
class _BarisChat extends StatelessWidget {
  const _BarisChat({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(order.serviceType);
    final warna = order.serviceType.warnaAloha;
    final ikon = order.serviceType.ikonAloha;
    final belumDibaca = order.jumlahPesanBelumDibaca;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: belumDibaca > 0
              ? const Color(0xFF86EFAC)
              : const Color(0xFFE5E7EB),
          width: belumDibaca > 0 ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push(Rute.chatOrder(order.id)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // AVATAR TEMATIK LAYANAN DENGAN INDIKATOR AKTIF
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: warna.latar,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(ikon, size: 22, color: warna.aksen),
                      ),
                    ),
                    if (order.status.isAktif)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00AA13),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // KONTEN CHAT (NAMA LAYANAN, KODE ORDER, WAKTU & STATUS)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    layanan.nama,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: belumDibaca > 0
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                      color: const Color(0xFF111827),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    order.kodeOrder,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatWaktuRelatif(order.dibuatPada),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: belumDibaca > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: belumDibaca > 0
                                  ? const Color(0xFF00AA13)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          LencanaStatus(status: order.status, compact: true),
                          const Spacer(),
                          if (belumDibaca > 0)
                            Badge.count(
                              count: belumDibaca,
                              backgroundColor: const Color(0xFF00AA13),
                              textColor: Colors.white,
                            )
                          else
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                        ],
                      ),
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

/// Chip tombol filter tab Chat Aloha
class _ChipTabChatAloha extends StatelessWidget {
  const _ChipTabChatAloha({
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
