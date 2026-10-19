import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/api/idempotency_key.dart';
import '../../../core/format/formatters.dart';
import '../../../core/providers/order_providers.dart';
import '../../../core/providers/payment_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/models/transaksi_pembayaran.dart';
import '../../../domain/service_catalog.dart';

/// Layar pembayaran Midtrans Snap dengan gaya Gojek Aloha.
///
/// Menyajikan kartu total tagihan, gerbang checkout Midtrans terenkripsi,
/// penghitung waktu mundur otomatis, rincian pesanan, dan tombol pembatalan.
/// Klien tidak perlu mengunggah bukti manual karena webhook server akan
/// memvalidasi pembayaran secara otomatis.
class PembayaranScreen extends ConsumerWidget {
  const PembayaranScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaksiAsync = ref.watch(transaksiOrderProvider(orderId));
    final isBerhasil = transaksiAsync.value?.berhasil ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: isBerhasil
          ? AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0.5,
              shadowColor: Colors.black.withValues(alpha: 0.05),
              leading: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF1F2937),
                  size: 24,
                ),
                onPressed: () => context.go(Rute.beranda),
              ),
              title: const Text(
                'Status Pembayaran',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => context.push(Rute.profil),
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF006C0E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0.5,
              shadowColor: Colors.black.withValues(alpha: 0.05),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF1F2937),
                  size: 22,
                ),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go(Rute.beranda);
                  }
                },
              ),
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pembayaran Midtrans',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00AA13),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Midtrans Snap Checkout',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 13),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EA),
                    borderRadius: BorderRadius.circular(100),
                    border:
                        Border.all(color: const Color(0xFFB7EBC1), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: Color(0xFF00880C),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Tersertifikasi',
                        style: TextStyle(
                          color: Color(0xFF00880C),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(
                    Icons.account_circle_outlined,
                    color: Color(0xFF4B5563),
                    size: 24,
                  ),
                  tooltip: 'Profil Saya',
                  onPressed: () => context.push(Rute.profil),
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: transaksiAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00AA13),
            strokeWidth: 3,
          ),
        ),
        error: (galat, _) => _PesanAloha(
          ikon: Icons.error_outline_rounded,
          warnaIkon: const Color(0xFFEF4444),
          judul: 'Pembayaran tidak bisa dimulai',
          keterangan: galat is GalatApi
              ? galat.pesan
              : 'Sambungan ke server terputus. Coba lagi, ya.',
          aksi: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00AA13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => ref.invalidate(transaksiOrderProvider(orderId)),
            child: const Text('Coba lagi'),
          ),
        ),
        data: (transaksi) => switch (transaksi.status) {
          _ when transaksi.berhasil => _BerhasilAloha(
            transaksi: transaksi,
            orderId: orderId,
          ),
          _ when transaksi.menunggu => _MenungguBayarAloha(
            transaksi: transaksi,
            orderId: orderId,
          ),
          _ => _PesanAloha(
            ikon: Icons.timer_off_outlined,
            warnaIkon: const Color(0xFFF59E0B),
            judul: 'Pembayaran kedaluwarsa',
            keterangan:
                'Batas waktu bayar sudah lewat. Buat ulang pembayaran untuk '
                'mendapatkan token transaksi baru.',
            aksi: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00AA13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => ref.invalidate(transaksiOrderProvider(orderId)),
              child: const Text('Buat Ulang Transaksi'),
            ),
          ),
        },
      ),
    );
  }
}

class _MenungguBayarAloha extends ConsumerWidget {
  const _MenungguBayarAloha({
    required this.transaksi,
    required this.orderId,
  });

  final TransaksiPembayaran transaksi;
  final String orderId;

  Future<void> _konfirmasiBatalkanOrder(
    BuildContext context,
    WidgetRef ref,
    Order? order,
  ) async {
    if (order == null) return;

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text(
              'Batalkan Pesanan?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        content: Text(
          'Pesanan #${order.kodeOrder} yang belum dibayar akan langsung dibatalkan. '
          'Kamu dapat membuat pesanan baru kapan saja.',
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF4B5563),
            height: 1.4,
          ),
        ),
        actionsPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
            ),
            child: const Text('Jangan'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (konfirmasi != true || !context.mounted) return;

    try {
      final key = buatIdempotencyKey();
      await ref
          .read(orderRepositoryProvider)
          .batalkanOrder(order.id, idempotencyKey: key);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Order #${order.kodeOrder} berhasil dibatalkan.'),
          ),
        );
      context.pushReplacement(Rute.detailOrder(order.id));
    } catch (galat) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi ? galat.pesan : 'Order gagal dibatalkan.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));
    final order = orderAsync.value;

    final namaLayanan = order?.serviceType != null
        ? serviceInfoOf(order!.serviceType).nama
        : 'Anter Jemput';
    final kodeOrderTampil = order?.kodeOrder ??
        (orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // 1. HERO TAGIHAN UTAMA
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Pill Status Pesanan
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEA580C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Menunggu Pembayaran • #$kodeOrderTampil',
                      style: const TextStyle(
                        color: Color(0xFFC2410C),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Total Tagihan $namaLayanan',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatRupiah(transaksi.jumlah),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00880C),
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              // Bebas Biaya Platform Mahasiswa Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EA),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFFC6F6D5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: Color(0xFF00AA13),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Bebas Biaya Platform Mahasiswa (Hemat Rp2.000)',
                      style: TextStyle(
                        color: Color(0xFF00880C),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFFF3F4F6), height: 1),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Metode Pembayaran Didukung:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _MetodePill(
                      label: 'GoPay',
                      accentColor: Color(0xFF00AED6),
                      iconData: Icons.account_balance_wallet_rounded,
                    ),
                    SizedBox(width: 8),
                    _MetodePill(
                      label: 'QRIS',
                      accentColor: Color(0xFFEA1C24),
                      iconData: Icons.qr_code_2_rounded,
                    ),
                    SizedBox(width: 8),
                    _MetodePill(
                      label: 'BCA VA',
                      accentColor: Color(0xFF005696),
                    ),
                    SizedBox(width: 8),
                    _MetodePill(
                      label: 'Mandiri',
                      accentColor: Color(0xFF003865),
                    ),
                    SizedBox(width: 8),
                    _MetodePill(
                      label: 'Kartu',
                      iconData: Icons.credit_card_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. CTA CARD - LANJUTKAN KE MIDTRANS SNAP
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F8EA),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.open_in_new_rounded,
                        color: Color(0xFF00AA13),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lanjutkan ke Midtrans Snap',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Gerbang Pembayaran Resmi & Terenkripsi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Kamu akan dialihkan ke antarmuka resmi Midtrans yang aman '
                'untuk memilih dan menyelesaikan transaksi menggunakan GoPay, QRIS, '
                'Virtual Account bank, atau Kartu.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 16),
              // ALOHA PRIMARY BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00AA13),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse(transaksi.checkoutUrl);
                    final terbuka = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!terbuka && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Halaman Midtrans tidak dapat dibuka.'),
                        ),
                      );
                    }
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Buka Gerbang Midtrans',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Security badges
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: Color(0xFF16A34A),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '256-bit SSL (Enkripsi Bank)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 14),
                  Text(
                    '•',
                    style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
                  ),
                  SizedBox(width: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 13,
                        color: Color(0xFF2563EB),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'OJK & BI (Terlisensi Resmi)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. SISA WAKTU PEMBAYARAN COUNTDOWN CARD
        _HitungMundurAloha(kedaluwarsaPada: transaksi.kedaluwarsaPada),

        const SizedBox(height: 14),

        // 4. DETAIL PESANAN CARD
        _DetailPesananAlohaCard(order: order, jumlah: transaksi.jumlah),

        const SizedBox(height: 20),

        // 5. TOMBOL BATALKAN PESANAN
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
              backgroundColor: const Color(0xFFFFF1F2),
              foregroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            onPressed: () => _konfirmasiBatalkanOrder(context, ref, order),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                SizedBox(width: 6),
                Text(
                  'Batalkan atau Ganti Pesanan',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // HELPDESK LINK
        Center(
          child: InkWell(
            onTap: () => context.push(Rute.pusatBantuan),
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Kendala pembayaran? Hubungi Helpdesk Kampus 24/7',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // SECURITY FOOTER
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 13, color: Color(0xFF9CA3AF)),
            SizedBox(width: 4),
            Text(
              'Enkripsi 256-bit Midtrans Shield',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
            ),
            SizedBox(width: 10),
            Text('•', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
            SizedBox(width: 10),
            Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF9CA3AF)),
            SizedBox(width: 4),
            Text(
              'Auto-Verifikasi',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetodePill extends StatelessWidget {
  const _MetodePill({
    required this.label,
    this.accentColor,
    this.iconData,
  });

  final String label;
  final Color? accentColor;
  final IconData? iconData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconData != null) ...[
            Icon(iconData, size: 14, color: accentColor ?? const Color(0xFF4B5563)),
            const SizedBox(width: 5),
          ] else if (accentColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _HitungMundurAloha extends StatefulWidget {
  const _HitungMundurAloha({required this.kedaluwarsaPada});

  final DateTime kedaluwarsaPada;

  @override
  State<_HitungMundurAloha> createState() => _HitungMundurAlohaState();
}

class _HitungMundurAlohaState extends State<_HitungMundurAloha> {
  Timer? _pewaktu;
  late Duration _sisa;

  @override
  void initState() {
    super.initState();
    _sisa = _hitung();
    _pewaktu = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final sisa = _hitung();
      setState(() => _sisa = sisa);
      if (sisa == Duration.zero) _pewaktu?.cancel();
    });
  }

  Duration _hitung() {
    final sisa = widget.kedaluwarsaPada.difference(DateTime.now());
    return sisa.isNegative ? Duration.zero : sisa;
  }

  @override
  void dispose() {
    _pewaktu?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habis = _sisa == Duration.zero;
    final menit = _sisa.inMinutes.toString().padLeft(2, '0');
    final detik = _sisa.inSeconds.remainder(60).toString().padLeft(2, '0');

    // Asumsi durasi jendela standar 30 menit (1800 detik) untuk progress bar
    const totalDetik = 1800;
    final rasioProgress =
        (_sisa.inSeconds / totalDetik).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: habis ? const Color(0xFFFCA5A5) : const Color(0xFFFED7AA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: habis
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.schedule_rounded,
                    color: habis
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFEA580C),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habis ? 'Waktu Bayar Berakhir' : 'Sisa Waktu Pembayaran',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      habis
                          ? 'Silakan buat ulang transaksi baru'
                          : 'Bayar sebelum ${formatJam(widget.kedaluwarsaPada)} WIB',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: habis
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(0xFFFCA5A5),
                    width: 1,
                  ),
                ),
                child: Text(
                  habis ? '00:00' : '$menit:$detik',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: habis
                        ? const Color(0xFF991B1B)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress Line
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: habis ? 0 : rasioProgress,
              backgroundColor: const Color(0xFFFFEDD5),
              color: habis ? const Color(0xFFEF4444) : const Color(0xFFEA580C),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Status pesanan akan terkonfirmasi otomatis via sistem UPNVJ '
                  'Suruh tanpa perlu unggah bukti transfer.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailPesananAlohaCard extends StatefulWidget {
  const _DetailPesananAlohaCard({
    required this.order,
    required this.jumlah,
  });

  final Order? order;
  final int jumlah;

  @override
  State<_DetailPesananAlohaCard> createState() => _DetailPesananAlohaCardState();
}

class _DetailPesananAlohaCardState extends State<_DetailPesananAlohaCard> {
  bool _terbuka = true;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final info = order?.serviceType != null ? serviceInfoOf(order!.serviceType) : null;
    final namaLayanan = info?.nama ?? 'Anter Jemput Kampus';
    final ikon = info?.icon ?? Icons.two_wheeler_rounded;

    final jarakText = order?.jarakKm != null
        ? '${order!.jarakKm!.toStringAsFixed(1)} km'
        : '2.4 km';
    final durasiText = order?.estimasiDurasi != null
        ? '${order!.estimasiDurasi!.inMinutes} Menit'
        : '15 Menit';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header clickable
          InkWell(
            onTap: () => setState(() => _terbuka = !_terbuka),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F8EA),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        ikon,
                        color: const Color(0xFF00AA13),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          namaLayanan,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Perjalanan $jarakText • ±$durasiText',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Detail',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00AA13),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _terbuka
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: const Color(0xFF00AA13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_terbuka) ...[
            const Divider(color: Color(0xFFF3F4F6), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rute Jemput & Antar
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Column(
                        children: [
                          Icon(
                            Icons.radio_button_checked_rounded,
                            size: 16,
                            color: Color(0xFF00AA13),
                          ),
                          SizedBox(
                            height: 24,
                            child: VerticalDivider(
                              color: Color(0xFFD1D5DB),
                              thickness: 1.5,
                            ),
                          ),
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order?.alamatJemput ??
                                  'Halte Busway Kampus UPNVJ Pondok Labu',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              order?.alamatTujuan ??
                                  'Gedung FISIP, Kampus UPNVJ Pondok Labu',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF3F4F6), height: 1),
                  const SizedBox(height: 14),

                  // Rincian Biaya
                  _BarisBiaya(
                    label: 'Tarif Dasar Layanan',
                    nilai: formatRupiah(widget.jumlah),
                  ),
                  const SizedBox(height: 8),
                  const _BarisBiaya(
                    label: 'Biaya Platform Layanan',
                    nilai: 'Rp 2.000',
                    dicoret: true,
                  ),
                  const SizedBox(height: 8),
                  const _BarisBiaya(
                    label: 'Subsidi Mahasiswa UPNVJ',
                    nilai: '-Rp 2.000',
                    warnaNilai: Color(0xFF00AA13),
                    tebalNilai: true,
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF3F4F6), height: 1),
                  const SizedBox(height: 12),
                  _BarisBiaya(
                    label: 'Total Pembayaran',
                    nilai: formatRupiah(widget.jumlah),
                    tebalLabel: true,
                    tebalNilai: true,
                    ukuranNilai: 15,
                    warnaNilai: const Color(0xFF00880C),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BarisBiaya extends StatelessWidget {
  const _BarisBiaya({
    required this.label,
    required this.nilai,
    this.dicoret = false,
    this.tebalLabel = false,
    this.tebalNilai = false,
    this.warnaNilai,
    this.ukuranNilai = 12.5,
  });

  final String label;
  final String nilai;
  final bool dicoret;
  final bool tebalLabel;
  final bool tebalNilai;
  final Color? warnaNilai;
  final double ukuranNilai;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: tebalLabel ? const Color(0xFF111827) : const Color(0xFF6B7280),
            fontWeight: tebalLabel ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          nilai,
          style: TextStyle(
            fontSize: ukuranNilai,
            color: dicoret
                ? const Color(0xFF9CA3AF)
                : (warnaNilai ?? const Color(0xFF1F2937)),
            fontWeight: tebalNilai ? FontWeight.w700 : FontWeight.w500,
            decoration: dicoret ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }
}

class _BerhasilAloha extends ConsumerWidget {
  const _BerhasilAloha({required this.transaksi, required this.orderId});

  final TransaksiPembayaran transaksi;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId)).value;
    final info = order?.serviceType != null
        ? serviceInfoOf(order!.serviceType)
        : null;
    final namaLayanan = order?.serviceType == ServiceType.anterJemput
        ? 'CampusRide'
        : (info?.nama ?? 'CampusRide');
    final deskripsiLayanan = order?.serviceType == ServiceType.anterJemput
        ? 'Anter Jemput Kampus Express'
        : (info?.deskripsi ?? 'Layanan Mahasiswa Kampus');
    final ikonLayanan = info?.icon ?? Icons.two_wheeler_rounded;

    final jarakText = order?.jarakKm != null
        ? '${order!.jarakKm!.toStringAsFixed(1)} km'
        : '3.5 km';

    final kodeOrderTampil = order?.kodeOrder ??
        (orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId);
    final kodeRef =
        'TRX-${transaksi.id.replaceAll('-', '').substring(0, 8).toUpperCase()}-$kodeOrderTampil';
    final waktuRef = '${formatTanggalJam(transaksi.dibuatPada)} WIB';

    final alamatJemputStr = order?.alamatJemput;
    final namaJemput = alamatJemputStr != null && alamatJemputStr.contains(',')
        ? alamatJemputStr.split(',').first.trim()
        : (alamatJemputStr ?? 'Indomaret RS Fatmawati');
    final detailJemput = alamatJemputStr ?? 'Pintu Barat, Halte Motor';

    final alamatTujuanStr = order?.alamatTujuan;
    final namaTujuan = alamatTujuanStr != null && alamatTujuanStr.contains(',')
        ? alamatTujuanStr.split(',').first.trim()
        : (alamatTujuanStr ?? 'UPN Veteran Jakarta - Kampus Limo');
    final detailTujuan =
        alamatTujuanStr ?? 'Lobby Gedung Wahidin Sudirohusodo';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        // 1. HERO CIRCLE CHECKMARK
        Center(
          child: Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F8EA),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: Color(0xFF00AA13),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. JUDUL & SUBTITLE
        const Text(
          'Pembayaran Berhasil!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Pesananmu sudah dikonfirmasi & langsung disiarkan ke runner kampus terdekat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 3. NOMINAL PEMBAYARAN JUMBO
        Text(
          formatRupiah(transaksi.jumlah),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: -0.8,
          ),
        ),

        const SizedBox(height: 10),

        // 4. LUNAS BADGE
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8EA),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0xFFC6F6D5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: Color(0xFF00AA13),
                ),
                SizedBox(width: 6),
                Text(
                  'Lunas via GoPay / Midtrans',
                  style: TextStyle(
                    color: Color(0xFF00880C),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 5. REF TRX PILL
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ref: $kodeRef • $waktuRef',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: kodeRef));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nomor referensi disalin.')),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 6. CARD 1: MENCARI RUNNER KAMPUS (LIVE STATUS BANNER)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.wifi_tethering_rounded,
                        color: Color(0xFF00AA13),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Mencari Runner Kampus...',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00AA13),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'Live',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Sistem sedang mencocokkan pesananmu dengan runner mahasiswa aktif di sekitar Kampus Limo / Fatmawati (±1–3 mnt).',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF374151),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: const LinearProgressIndicator(
                  value: 0.65,
                  backgroundColor: Color(0xFFDCFCE7),
                  color: Color(0xFF00AA13),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 7. CARD 2: SUMMARY & ROUTE CARD (CAMPUSRIDE / ANTER JEMPUT)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Layanan
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F8EA),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        ikonLayanan,
                        color: const Color(0xFF00AA13),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          namaLayanan,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          deskripsiLayanan,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8EA),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFFC6F6D5)),
                    ),
                    child: const Text(
                      'Mahasiswa',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00880C),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(color: Color(0xFFF3F4F6), height: 1),
              const SizedBox(height: 14),

              // Rute Antar Jemput
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.circle,
                      size: 10,
                      color: Color(0xFF00AA13),
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
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          namaJemput,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          detailJemput,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: SizedBox(
                  height: 18,
                  child: VerticalDivider(
                    color: Color(0xFFE5E7EB),
                    thickness: 2,
                  ),
                ),
              ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TUJUAN ANTAR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          namaTujuan,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          detailTujuan,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(color: Color(0xFFF3F4F6), height: 1),
              const SizedBox(height: 12),

              // Rincian Biaya
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tarif Dasar ($jarakText)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    formatRupiah(transaksi.jumlah),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Biaya Layanan Kampus ',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                      ),
                      children: [
                        TextSpan(
                          text: 'Rp 2.000',
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Gratis Promo',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00AA13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: Color(0xFFF3F4F6), height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Dibayar',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Status: LUNAS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF00880C),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    formatRupiah(transaksi.jumlah),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 8. CARD 3: JAMINAN AMANAH BANNER
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF00880C),
                    size: 16,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Jaminan Amanah: Runner merupakan mahasiswa UPNVJ resmi dengan Kartu Tanda Mahasiswa (KTM) terverifikasi.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF374151),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 9. UNDUH BUKTI PEMBAYARAN RESMI (PDF)
        Center(
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Bukti pembayaran resmi disiapkan untuk diunduh.'),
                ),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: Color(0xFF4B5563),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Unduh Bukti Pembayaran Resmi (PDF)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.download_rounded,
                    size: 16,
                    color: Color(0xFF4B5563),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 10. ALOHA PRIMARY PILL BUTTON
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00AA13),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            onPressed: () => context.pushReplacement(Rute.detailOrder(orderId)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Pantau Runner & Pesanan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 11. SECONDARY LINK: KEMBALI KE BERANDA
        Center(
          child: InkWell(
            onTap: () => context.go(Rute.beranda),
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Kembali ke Beranda',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PesanAloha extends StatelessWidget {
  const _PesanAloha({
    required this.ikon,
    required this.warnaIkon,
    required this.judul,
    required this.keterangan,
    this.aksi,
  });

  final IconData ikon;
  final Color warnaIkon;
  final String judul;
  final String keterangan;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiBesar),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: warnaIkon.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(ikon, size: 36, color: warnaIkon),
              ),
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            if (aksi != null) ...[
              const SizedBox(height: AppTheme.spasiBesar),
              aksi!,
            ],
          ],
        ),
      ),
    );
  }
}
