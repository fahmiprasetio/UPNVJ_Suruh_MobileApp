import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../domain/enums.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/models/order_offer.dart';
import '../../../../domain/service_catalog.dart';

/// Satu tawaran yang sudah dikirim runner dengan visual Aloha Gojek yang rapi,
/// elegan, dan proporsional.
class KartuTawaranRunner extends StatelessWidget {
  const KartuTawaranRunner({
    super.key,
    required this.order,
    required this.penawaran,
    this.onTarik,
    this.tarikSedangDiproses = false,
    this.onChat,
  });

  final Order order;
  final OrderOffer penawaran;

  /// Hanya ada selama tawarannya masih bisa ditarik. Yang sudah disetujui tidak:
  /// harga ordernya sudah ditetapkan dari tawaran ini dan klien mungkin sedang
  /// membayarnya.
  final VoidCallback? onTarik;

  /// Benar selama permintaan pencabutan tawaran masih menunggu jawaban server.
  final bool tarikSedangDiproses;

  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(order.serviceType);

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
              // 1. HEADER: IKON CIRCULAR + JUDUL & KODE ORDER + BADGE STATUS TAWARAN
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFDF2F8),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.local_offer_rounded,
                        color: Color(0xFFDB2777),
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
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
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
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
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BadgeStatusTawaran(status: penawaran.status),
                ],
              ),

              // 2. DESKRIPSI PERMINTAAN KLIEN (KOMPAK)
              if (order.deskripsi != null && order.deskripsi!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.format_quote_rounded,
                        size: 14,
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

              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 10),

              // 3. NOMINAL TAWARAN RUNNER
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    'Kamu menawar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatRupiah(penawaran.harga),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00AA13),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 4. KETERANGAN STATUS DINAMIS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_ikon, size: 14, color: const Color(0xFF6B7280)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _keterangan,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF4B5563),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. TOMBOL AKSI (CHAT KLIEN & TARIK TAWARAN)
              if (onTarik != null || onChat != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (onChat != null)
                      SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: onChat,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00880C),
                            side: const BorderSide(
                              color: Color(0xFF00AA13),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.forum_outlined, size: 15),
                          label: Text(
                            order.jumlahPesanBelumDibaca == 0
                                ? 'Chat Klien'
                                : 'Chat Klien (${order.jumlahPesanBelumDibaca})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (onTarik != null)
                      TextButton(
                        onPressed: tarikSedangDiproses ? null : onTarik,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          foregroundColor: const Color(0xFF6B7280),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: tarikSedangDiproses
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF6B7280),
                                ),
                              )
                            : const Text(
                                'Tarik tawaran',
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
          ),
        ),
      ),
    );
  }

  IconData get _ikon => switch (penawaran.status) {
    OfferStatus.disetujui => Icons.check_circle_outline,
    OfferStatus.dinegoUlang => Icons.reply_outlined,
    _ => Icons.hourglass_top_outlined,
  };

  String get _keterangan => switch (penawaran.status) {
    OfferStatus.disetujui =>
      'Tawaranmu dipilih. Ordermu mulai begitu klien melunasi.',
    OfferStatus.dinegoUlang =>
      'Klien minta dihitung ulang. Alasannya ada di chat; tarik tawaran ini '
          'lalu kirim angka baru.',
    _ => 'Menunggu jawaban klien.',
  };
}

/// Lencana status tawaran ala Aloha Gojek
class _BadgeStatusTawaran extends StatelessWidget {
  const _BadgeStatusTawaran({required this.status});

  final OfferStatus status;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color teks, String label, IconData ikon}) konfigurasi =
        switch (status) {
      OfferStatus.disetujui => (
          bg: const Color(0xFFE8F8EA),
          teks: const Color(0xFF00AA13),
          label: 'Disetujui',
          ikon: Icons.check_circle_rounded,
        ),
      OfferStatus.dinegoUlang => (
          bg: const Color(0xFFEFF6FF),
          teks: const Color(0xFF2563EB),
          label: 'Nego Ulang',
          ikon: Icons.replay_rounded,
        ),
      _ => (
          bg: const Color(0xFFFEF3C7),
          teks: const Color(0xFFD97706),
          label: 'Menunggu',
          ikon: Icons.hourglass_top_rounded,
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
