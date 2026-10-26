import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/providers/tracking_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/foto_estimasi_order.dart';
import '../../../../domain/enums.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/service_catalog.dart';

/// Satu order yang dipegang runner dengan bahasa desain Aloha Gojek yang modern,
/// bersih, dan hemat ruang vertikal.
class KartuOrderRunner extends StatelessWidget {
  const KartuOrderRunner({
    super.key,
    required this.order,
    this.onSelesaikan,
    this.onLepas,
    this.lepasSedangDiproses = false,
    this.onChat,
  });

  final Order order;

  /// `null` untuk order yang sudah selesai.
  final VoidCallback? onSelesaikan;

  /// Runner melepas order yang sedang berjalan.
  final VoidCallback? onLepas;

  /// Status proses mutasi pelepasan order.
  final bool lepasSedangDiproses;

  /// Pintu menuju ruang obrolan pesanan.
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(order.serviceType);
    final warna = _warnaLayanan(order.serviceType);
    final ikon = _ikonLayanan(order.serviceType, layanan.icon);
    final adaRute = order.alamatJemput != null || order.alamatTujuan != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER: IKON LAYANAN + NAMA & KODE ORDER + BADGE STATUS
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: warna.latar,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(ikon, color: warna.aksen, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                layanan.nama,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
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
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4B5563),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 13,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                order.namaKlien,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6B7280),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BadgeStatusAloha(status: order.status),
                ],
              ),

              // 2. CATATAN / DESKRIPSI KLIEN (KOMPAK)
              if (order.deskripsi != null && order.deskripsi!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.deskripsi!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF374151),
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 3. RUTE JEMPUT & TUJUAN (ALOHA GOJEK - RINGKAS & TIDAK MENUHIN LAYAR)
              if (adaRute) ...[
                const SizedBox(height: 12),
                _RuteKompakAloha(
                  jemput: order.alamatJemput,
                  tujuan: order.alamatTujuan,
                ),
              ],

              // 4. KENDARAAN (JIKA ADA)
              if (order.jenisKendaraan != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Kendaraan: ${order.jenisKendaraan!.label}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],

              // 5. FOTO ESTIMASI
              if (order.fotoEstimasiUrl != null) ...[
                const SizedBox(height: 12),
                FotoEstimasiOrder(order: order, height: 140),
              ],

              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 12),

              // 6. HARGA & AKSI
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tarif Bersih Runner',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatRupiah(order.harga),
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onSelesaikan == null && onChat != null)
                    _TombolChatAloha(
                      onChat: onChat!,
                      jumlahPesanBelumDibaca: order.jumlahPesanBelumDibaca,
                    ),
                ],
              ),

              // 7. RINGKASAN PENYELESAIAN (UNTUK ORDER SELESAI)
              if (onSelesaikan == null) ...[
                const SizedBox(height: 10),
                _RingkasanPenyelesaian(order: order),
              ],

              // 8. TOMBOL UTAMA & AKSI SAMPING (UNTUK ORDER SEDANG DIKERJAKAN)
              if (onSelesaikan != null) ...[
                const SizedBox(height: 14),
                Consumer(
                  builder: (context, ref, _) {
                    final isRuteService =
                        order.serviceType == ServiceType.anterJemput ||
                        order.serviceType == ServiceType.jastipMakanan;
                    final tahap = isRuteService
                        ? (ref.watch(tahapTrackingProvider)[order.id] ??
                            TahapTrackingOrder.menujuJemput)
                        : TahapTrackingOrder.sedangAntar;

                    if (isRuteService &&
                        tahap == TahapTrackingOrder.menujuJemput) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ref
                                    .read(tahapTrackingProvider.notifier)
                                    .mulaiAntar(order.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Perjalanan dimulai! Rute hijau live tracking kini mengarah ke tujuan.',
                                    ),
                                    backgroundColor: Color(0xFF00880C),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00AA13),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.navigation_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Mulai Antar ke Tujuan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    context.push(Rute.detailOrder(order.id)),
                                icon: const Icon(
                                  Icons.map_rounded,
                                  size: 15,
                                  color: Color(0xFF00880C),
                                ),
                                label: const Text(
                                  'Buka Peta Live',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF00880C),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: onSelesaikan,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF6B7280),
                                ),
                                child: const Text(
                                  'Selesaikan Order',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRuteService) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8EA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.navigation_rounded,
                                  size: 14,
                                  color: Color(0xFF00AA13),
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Rute pengantaran ke tujuan aktif di live tracking',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF00880C),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref
                                        .read(tahapTrackingProvider.notifier)
                                        .kembaliKeJemput(order.id);
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 24),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text(
                                    'Batal',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: onSelesaikan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00AA13),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.task_alt_rounded, size: 18),
                            label: const Text(
                              'Selesaikan Order',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                        if (isRuteService)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton.icon(
                              onPressed: () =>
                                  context.push(Rute.detailOrder(order.id)),
                              icon: const Icon(
                                Icons.map_rounded,
                                size: 15,
                                color: Color(0xFF00880C),
                              ),
                              label: const Text(
                                'Buka Peta Live Tracking',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF00880C),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (onChat != null || onLepas != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (onChat != null)
                        TextButton.icon(
                          onPressed: onChat,
                          icon: const Icon(
                            Icons.forum_outlined,
                            size: 16,
                            color: Color(0xFF00880C),
                          ),
                          label: Text(
                            order.jumlahPesanBelumDibaca == 0
                                ? 'Chat Klien'
                                : 'Chat Klien (${order.jumlahPesanBelumDibaca})',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00880C),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                      const Spacer(),
                      if (onLepas != null)
                        TextButton(
                          onPressed: lepasSedangDiproses ? null : onLepas,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 36),
                          ),
                          child: lepasSedangDiproses
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFEF4444),
                                  ),
                                )
                              : const Text(
                                  'Lepas order',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
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

  static IconData _ikonLayanan(ServiceType type, IconData bawaan) {
    switch (type) {
      case ServiceType.anterJemput:
        return Icons.two_wheeler_rounded;
      case ServiceType.jastipMakanan:
        return Icons.restaurant_rounded;
      case ServiceType.jastipBarang:
        return Icons.shopping_bag_rounded;
      case ServiceType.bersihKamarMandi:
        return Icons.bathtub_rounded;
      case ServiceType.bersihKos:
        return Icons.cleaning_services_rounded;
      case ServiceType.bantuPindahKos:
        return Icons.local_shipping_rounded;
      case ServiceType.permintaanLain:
        return Icons.edit_note_rounded;
    }
  }
}

/// Lencana status ringkas ala Aloha Gojek
class _BadgeStatusAloha extends StatelessWidget {
  const _BadgeStatusAloha({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color teks, String label, IconData ikon}) konfigurasi =
        switch (status) {
      OrderStatus.dikerjakan => (
          bg: const Color(0xFFE8F8EA),
          teks: const Color(0xFF00AA13),
          label: 'Dikerjakan',
          ikon: Icons.directions_bike_rounded,
        ),
      OrderStatus.selesai => (
          bg: const Color(0xFFF0FDF4),
          teks: const Color(0xFF059669),
          label: 'Selesai',
          ikon: Icons.check_circle_rounded,
        ),
      OrderStatus.batal => (
          bg: const Color(0xFFFEE2E2),
          teks: const Color(0xFFDC2626),
          label: 'Batal',
          ikon: Icons.cancel_rounded,
        ),
      _ => (
          bg: const Color(0xFFF3F4F6),
          teks: const Color(0xFF4B5563),
          label: status.name,
          ikon: Icons.info_outline_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: konfigurasi.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(konfigurasi.ikon, size: 12, color: konfigurasi.teks),
          const SizedBox(width: 4),
          Text(
            konfigurasi.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: konfigurasi.teks,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rute ringkas modern tanpa teks panjang berlebih
class _RuteKompakAloha extends StatelessWidget {
  const _RuteKompakAloha({required this.jemput, required this.tujuan});

  final String? jemput;
  final String? tujuan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (jemput != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00AA13), width: 3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jemput',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF00880C),
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        jemput!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (jemput != null && tujuan != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                width: 2,
                height: 12,
                color: const Color(0xFFD1D5DB),
              ),
            ),
          ],
          if (tujuan != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 15,
                  color: Color(0xFFEA580C),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tujuan',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEA580C),
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        tujuan!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tombol Chat Aloha untuk footer
class _TombolChatAloha extends StatelessWidget {
  const _TombolChatAloha({
    required this.onChat,
    required this.jumlahPesanBelumDibaca,
  });

  final VoidCallback onChat;
  final int jumlahPesanBelumDibaca;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        onPressed: onChat,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF00880C),
          side: const BorderSide(color: Color(0xFF00AA13), width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.forum_outlined, size: 15),
        label: Text(
          jumlahPesanBelumDibaca == 0
              ? 'Chat Klien'
              : 'Chat Klien ($jumlahPesanBelumDibaca)',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Ringkasan penyelesaian bersih, rapi dan mempertahankan teks ekspektasi test
class _RingkasanPenyelesaian extends StatelessWidget {
  const _RingkasanPenyelesaian({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: Color(0xFF00AA13),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.selesaiPada == null
                      ? 'Selesai'
                      : 'Selesai ${formatTanggalJam(order.selesaiPada!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
          if (order.fotoBuktiUrl != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 13,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Foto bukti tersimpan',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
          if (order.catatanSerahTerima != null &&
              order.catatanSerahTerima!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.notes_rounded,
                  size: 13,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Catatan: ${order.catatanSerahTerima!}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
