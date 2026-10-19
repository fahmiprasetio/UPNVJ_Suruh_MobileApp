import 'package:flutter/material.dart';

import '../../../../domain/enums.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/order_flow.dart';

/// Linimasa status pemesanan dengan gaya Gojek Aloha.
///
/// Menyajikan tahapan visual dengan ikon khusus, teks status, keterangan
/// langkah, serta konektor garis berurutan yang dinamis.
class LinimasaStatus extends StatelessWidget {
  const LinimasaStatus({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    if (order.dibatalkan) return const _OrderDibatalkan();

    final tahapan = order.alur;
    return Column(
      children: [
        for (var i = 0; i < tahapan.length; i++)
          _TahapAloha(
            status: tahapan[i],
            order: order,
            sudahLewat: order.sudahLewat(tahapan[i]) ||
                (order.status == OrderStatus.selesai &&
                    order.sedangDi(tahapan[i])),
            sedangDi: order.sedangDi(tahapan[i]) &&
                order.status != OrderStatus.selesai,
            tahapTerakhir: i == tahapan.length - 1,
            garisHijau: order.sudahLewat(tahapan[i]) ||
                order.sedangDi(tahapan[i]),
          ),
      ],
    );
  }
}

class _TahapAloha extends StatelessWidget {
  const _TahapAloha({
    required this.status,
    required this.order,
    required this.sudahLewat,
    required this.sedangDi,
    required this.tahapTerakhir,
    required this.garisHijau,
  });

  final OrderStatus status;
  final Order order;
  final bool sudahLewat;
  final bool sedangDi;
  final bool tahapTerakhir;
  final bool garisHijau;

  (IconData ikon, String judul, String keterangan) _infoTahap() {
    final tujuanSingkat = order.alamatTujuan != null &&
            order.alamatTujuan!.isNotEmpty
        ? (order.alamatTujuan!.length > 30
            ? '${order.alamatTujuan!.substring(0, 30)}...'
            : order.alamatTujuan!)
        : 'tujuan pengantaran';

    return switch (status) {
      OrderStatus.permintaan => (
        Icons.handshake_outlined,
        'Mencari Penawaran',
        'Menunggu tawaran harga dan kesediaan jadwal dari runner kampus',
      ),
      OrderStatus.menungguPembayaran => (
        Icons.payment_rounded,
        'Menunggu Pembayaran',
        'Konfirmasi pembayaran untuk mengirim order ke runner',
      ),
      OrderStatus.mencariRunner => (
        Icons.person_search_rounded,
        'Mencari Runner Kampus',
        'Runner mahasiswa terdekat di area kampus siap ditugaskan',
      ),
      OrderStatus.dikerjakan => (
        order.serviceType == ServiceType.anterJemput
            ? Icons.two_wheeler_rounded
            : Icons.work_outline_rounded,
        order.serviceType == ServiceType.anterJemput
            ? 'Perjalanan ke Tujuan'
            : 'Sedang Dikerjakan',
        order.serviceType == ServiceType.anterJemput
            ? 'Perjalanan dimulai setelah kamu dijemput'
            : 'Runner sedang menyelesaikan pekerjaan pesananmu',
      ),
      OrderStatus.selesai => (
        Icons.check_circle_outline_rounded,
        'Selesai',
        'Tiba dengan selamat di $tujuanSingkat',
      ),
      OrderStatus.batal => (
        Icons.cancel_outlined,
        'Dibatalkan',
        'Pesanan telah dibatalkan',
      ),
      _ => (
        Icons.radio_button_checked_rounded,
        status.label,
        'Status pesanan saat ini',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (ikon, judul, keterangan) = _infoTahap();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kolom Ikon & Garis Penghubung
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: sedangDi
                    ? const Color(0xFF00880C)
                    : (sudahLewat
                        ? const Color(0xFF00AA13)
                        : const Color(0xFFF3F4F6)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: sedangDi || sudahLewat
                      ? const Color(0xFF00AA13)
                      : const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  sudahLewat ? Icons.check_rounded : ikon,
                  size: 18,
                  color: sedangDi || sudahLewat
                      ? Colors.white
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
            if (!tahapTerakhir)
              Container(
                width: 2,
                height: 38,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: garisHijau
                    ? const Color(0xFF00AA13)
                    : const Color(0xFFE5E7EB),
              ),
          ],
        ),
        const SizedBox(width: 14),
        // Kolom Deskripsi Teks
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: tahapTerakhir ? 0 : 16,
              top: 4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      judul,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: sedangDi
                            ? FontWeight.w800
                            : (sudahLewat ? FontWeight.w700 : FontWeight.w600),
                        color: sedangDi
                            ? const Color(0xFF111827)
                            : (sudahLewat
                                ? const Color(0xFF1F2937)
                                : const Color(0xFF4B5563)),
                      ),
                    ),
                    if (sedangDi) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00AA13),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  keterangan,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: sedangDi
                        ? const Color(0xFF00880C)
                        : (sudahLewat
                            ? const Color(0xFF4B5563)
                            : const Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderDibatalkan extends StatelessWidget {
  const _OrderDibatalkan();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Dibatalkan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF991B1B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pesanan ini sudah tidak aktif atau dibatalkan oleh klien/admin.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
