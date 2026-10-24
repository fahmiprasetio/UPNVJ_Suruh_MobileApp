import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/foto_estimasi_order.dart';
import '../../../../domain/enums.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/service_catalog.dart';

/// Satu order yang sedang disiarkan, dilihat dari sisi runner dengan gaya modern Gojek Aloha.
///
/// Kartu menampilkan identitas layanan dengan palet warna Aloha, rute penjemputan
/// dan tujuan yang visual dan jelas, estimasi jarak, catatan pemesan, dan tombol
/// aksi "TERIMA ORDER" hijau Gojek yang responsif dan empuk.
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
    final adaRute = order.alamatJemput != null || order.alamatTujuan != null;
    final warna = _warnaLayanan(order.serviceType);
    final ikon = _ikonLayanan(order.serviceType, layanan.icon);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
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
              // 1. HEADER: ICON LAYANAN + NAMA & KODE ORDER + UMUR SIARAN
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: warna.latar,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(ikon, color: warna.aksen, size: 21),
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
                  // Waktu Relatif / Umur Siaran
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatWaktuRelatif(order.dibuatPada),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 2. DESKRIPSI / CATATAN PESANAN (Jika Ada)
              if (order.deskripsi != null &&
                  order.deskripsi!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
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
                        Icons.sticky_note_2_outlined,
                        size: 14,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.deskripsi!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF374151),
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (order.fotoEstimasiUrl != null) ...[
                const SizedBox(height: 12),
                FotoEstimasiOrder(order: order, height: 160),
              ],

              if (order.jenisKendaraan != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Kendaraan: ${order.jenisKendaraan!.label}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],

              // 3. BLOK RUTE ALOHA (Jemput & Tujuan dengan Pin & Indikator Jarak)
              if (adaRute) ...[
                const SizedBox(height: 12),
                _BlokRuteAloha(
                  jemput: order.alamatJemput,
                  tujuan: order.alamatTujuan,
                  jarakKm: order.jarakKm,
                ),
              ],

              // 4. LENCANA KUOTA (Jika butuh lebih dari 1 runner)
              if (order.jumlahRunnerDibutuhkan > 1) ...[
                const SizedBox(height: 10),
                _LencanaKuotaAloha(order: order),
              ],

              const SizedBox(height: 14),

              // Garis pemisah halus
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),

              const SizedBox(height: 14),

              // 5. FOOTER: TARIF BERSIH & TOMBOL TERIMA HIJAU GOJEK
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _menungguTawaran
                              ? 'Usulan Penawaran Klien'
                              : 'Tarif Bersih Runner',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatRupiah(
                            _menungguTawaran ? order.hargaUsulan : order.harga,
                          ),
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _menungguTawaran
                      ? _TombolTawarAloha(orderId: order.id)
                      : _TombolTerimaAloha(
                          sedangDiproses: sedangDiproses,
                          onTerima: onTerima,
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _menungguTawaran =>
      order.track == OrderTrack.jalurB &&
      order.status == OrderStatus.permintaan;

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
        return (latar: const Color(0xFFF1F5F9), aksen: const Color(0xFF475569));
    }
  }

  static IconData _ikonLayanan(ServiceType type, IconData bawaan) {
    switch (type) {
      case ServiceType.anterJemput:
        return Icons.two_wheeler_rounded;
      case ServiceType.jastipMakanan:
        return Icons.lunch_dining_rounded;
      case ServiceType.jastipBarang:
        return Icons.shopping_bag_outlined;
      case ServiceType.bersihKamarMandi:
        return Icons.bathtub_outlined;
      case ServiceType.bersihKos:
        return Icons.cleaning_services_rounded;
      case ServiceType.bantuPindahKos:
        return Icons.local_shipping_outlined;
      case ServiceType.permintaanLain:
        return Icons.more_horiz_rounded;
    }
  }
}

/// Visual Rute Jemput-Tujuan gaya Gojek Aloha dengan konektor titik dan jarak
class _BlokRuteAloha extends StatelessWidget {
  const _BlokRuteAloha({this.jemput, this.tujuan, this.jarakKm});

  final String? jemput;
  final String? tujuan;
  final double? jarakKm;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (jemput != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00AA13),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFC6F6D5),
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TITIK JEMPUT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF00880C),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        jemput!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (jarakKm != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8EA),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFFC6F6D5)),
                    ),
                    child: Text(
                      '${jarakKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00880C),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (jemput != null && tujuan != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                width: 2,
                height: 16,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: const Color(0xFFCBD5E1),
              ),
            ),
          if (tujuan != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFEDD5),
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TITIK TUJUAN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEA580C),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        tujuan!,
                        style: const TextStyle(
                          fontSize: 13,
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

/// Tombol TERIMA ORDER berwarna Hijau Gojek Aloha yang empuk dan jelas
class _TombolTerimaAloha extends StatelessWidget {
  const _TombolTerimaAloha({
    required this.sedangDiproses,
    required this.onTerima,
  });

  final bool sedangDiproses;
  final VoidCallback onTerima;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: sedangDiproses ? null : onTerima,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00AA13),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF86EFAC),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: sedangDiproses
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'TERIMA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Tombol Ajukan Tawaran untuk pesanan Jalur B
class _TombolTawarAloha extends StatelessWidget {
  const _TombolTawarAloha({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: () => context.push(Rute.ajukanTawaran(orderId)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF00880C),
          side: const BorderSide(color: Color(0xFF00AA13), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.gavel_rounded, size: 16),
        label: const Text(
          'TAWAR',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// Lencana kuota tim pelaksana
class _LencanaKuotaAloha extends StatelessWidget {
  const _LencanaKuotaAloha({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people_outline_rounded,
            size: 13,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 4),
          Text(
            'Butuh ${order.jumlahRunnerDibutuhkan} orang • '
            '${order.runnerIds.length} bergabung',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E40AF),
            ),
          ),
        ],
      ),
    );
  }
}
