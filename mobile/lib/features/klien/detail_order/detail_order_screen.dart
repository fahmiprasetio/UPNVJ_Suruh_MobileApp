import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/api/idempotency_key.dart';
import '../../../core/config/batas_masukan.dart';
import '../../../core/format/formatters.dart';
import '../../../core/providers/order_providers.dart';
import '../../../core/providers/payment_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pesan_kosong.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/service_catalog.dart';
import '../buka_form_order.dart';
import 'widgets/kartu_bukti_pekerjaan.dart';
import 'widgets/kartu_penawaran.dart';
import 'widgets/linimasa_status.dart';

/// Detail satu order: status, linimasa pemesanan, dan rincian perjalanan
/// dengan gaya Gojek Aloha sesuai spesifikasi referensi desain.
class DetailOrderScreen extends ConsumerWidget {
  const DetailOrderScreen({super.key, required this.orderId});

  final String orderId;

  Widget? _bilahTindakan(Order? order) {
    if (order == null) return null;
    if (order.status == OrderStatus.menungguPembayaran) {
      return _BilahBayarAloha(order: order);
    }
    if (!order.status.isAktif && adaFormOrder(order.serviceType)) {
      return _BilahPesanLagiAloha(order: order);
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));
    final order = orderAsync.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
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
        title: order == null
            ? const Text(
                'Detail Order',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EA),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFFC6F6D5)),
                ),
                child: Text(
                  order.kodeOrder,
                  style: const TextStyle(
                    color: Color(0xFF00880C),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.headset_mic_outlined,
              color: Color(0xFF4B5563),
              size: 22,
            ),
            tooltip: 'Pusat Bantuan',
            onPressed: () => context.push(Rute.pusatBantuan),
          ),
          if (order != null &&
              !(order.track == OrderTrack.jalurB &&
                  order.status == OrderStatus.permintaan))
            _TombolChatAloha(order: order),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
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
      ),
      body: orderAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00AA13),
            strokeWidth: 3,
          ),
        ),
        error: (galat, _) => PesanKosong(
          ikon: Icons.wifi_off_outlined,
          judul: 'Order gagal dimuat',
          keterangan: galat is GalatApi
              ? galat.pesan
              : 'Sambungan ke server terputus.',
          labelAksi: 'Coba lagi',
          onAksi: () => ref.invalidate(orderProvider(orderId)),
        ),
        data: (order) => order == null
            ? const Center(child: Text('Order tidak ditemukan.'))
            : _IsiAloha(order: order),
      ),
      bottomNavigationBar: _bilahTindakan(order),
    );
  }
}

class _TombolChatAloha extends StatelessWidget {
  const _TombolChatAloha({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final jumlah = order.jumlahPesanBelumDibaca;
    return IconButton(
      onPressed: () => context.push(Rute.chatOrder(order.id)),
      tooltip: 'Chat Order',
      icon: Badge.count(
        count: jumlah,
        isLabelVisible: jumlah > 0,
        backgroundColor: const Color(0xFFDC2626),
        child: const Icon(
          Icons.chat_bubble_outline_rounded,
          color: Color(0xFF4B5563),
          size: 22,
        ),
      ),
    );
  }
}

class _IsiAloha extends ConsumerWidget {
  const _IsiAloha({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layanan = serviceInfoOf(order.serviceType);
    final penawaranPending = order.penawaranPending;

    final namaLayananTampil = order.serviceType == ServiceType.anterJemput
        ? 'Campu • Anter Jemput'
        : layanan.nama;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        // 1. SERVICE & META HEADER
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
                  layanan.icon,
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
                    namaLayananTampil,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatTanggalJam(order.dibuatPada)} WIB',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: Color(0xFFEA580C),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    order.status.label,
                    style: const TextStyle(
                      color: Color(0xFFC2410C),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 2. COUNTDOWN ALERT BANNER (Hanya jika menunggu pembayaran)
        if (order.status == OrderStatus.menungguPembayaran) ...[
          _HitungMundurDetailOrder(order: order),
          const SizedBox(height: 12),
        ],

        // 3. TOTAL PEMBAYARAN CARD
        _TotalPembayaranCard(order: order),

        const SizedBox(height: 16),

        // 4. STATUS PEMESANAN (LINIMASA STEPPER ALOHA)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Status Pemesanan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              'ID: ${order.kodeOrder}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
          child: LinimasaStatus(order: order),
        ),

        // Tawaran Pending Jalur B (jika ada)
        for (final tawaran in penawaranPending) ...[
          const SizedBox(height: 14),
          KartuPenawaran(order: order, penawaran: tawaran),
        ],

        // Bukti Pekerjaan (jika sudah selesai)
        if (order.fotoBuktiUrl != null || order.catatanSerahTerima != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Hasil Pekerjaan Runner',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          KartuBuktiPekerjaan(order: order),
        ],

        const SizedBox(height: 16),

        // 5. RINCIAN PERJALANAN CARD
        if (order.alamatJemput != null || order.alamatTujuan != null) ...[
          _RincianPerjalananCard(order: order),
          const SizedBox(height: 14),
        ],

        // 6. JAMINAN RUNNER TERVERIFIKASI
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F8EA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFC6F6D5)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF00880C),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jaminan Runner Terverifikasi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Runner adalah mahasiswa aktif dengan ID Kampus terverifikasi.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 7. JALAN BATAL (OPSIONAL / SCROLLABLE)
        _JalanBatal(order: order),
      ],
    );
  }
}

class _HitungMundurDetailOrder extends ConsumerStatefulWidget {
  const _HitungMundurDetailOrder({required this.order});

  final Order order;

  @override
  ConsumerState<_HitungMundurDetailOrder> createState() =>
      _HitungMundurDetailOrderState();
}

class _HitungMundurDetailOrderState
    extends ConsumerState<_HitungMundurDetailOrder> {
  Timer? _pewaktu;
  late Duration _sisa;
  late DateTime _batasWaktu;

  @override
  void initState() {
    super.initState();
    _batasWaktu = widget.order.dibuatPada.add(const Duration(minutes: 30));
    _sisa = _hitung();

    _pewaktu = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final sisa = _hitung();
      setState(() => _sisa = sisa);
      if (sisa == Duration.zero) _pewaktu?.cancel();
    });
  }

  Duration _hitung() {
    final sisa = _batasWaktu.difference(DateTime.now());
    return sisa.isNegative ? Duration.zero : sisa;
  }

  @override
  void dispose() {
    _pewaktu?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sinkronkan dengan batas waktu transaksi Midtrans dari provider jika ada
    final transaksiAsync =
        ref.watch(transaksiOrderProvider(widget.order.id));
    if (transaksiAsync.hasValue &&
        transaksiAsync.value?.kedaluwarsaPada != null) {
      _batasWaktu = transaksiAsync.value!.kedaluwarsaPada;
    }

    final habis = _sisa == Duration.zero;
    final menit = _sisa.inMinutes.toString().padLeft(2, '0');
    final detik = _sisa.inSeconds.remainder(60).toString().padLeft(2, '0');

    const totalDetik = 1800;
    final rasio = (_sisa.inSeconds / totalDetik).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.alarm_rounded,
                color: Color(0xFFEA580C),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Selesaikan pembayaran dalam',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Text(
                habis ? '00:00' : '$menit : $detik',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: habis ? 0 : rasio,
              backgroundColor: const Color(0xFFFFEDD5),
              color: const Color(0xFFEA580C),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesanan akan otomatis dibatalkan jika tidak dibayar sebelum ${formatJam(_batasWaktu)} WIB.',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalPembayaranCard extends StatefulWidget {
  const _TotalPembayaranCard({required this.order});

  final Order order;

  @override
  State<_TotalPembayaranCard> createState() => _TotalPembayaranCardState();
}

class _TotalPembayaranCardState extends State<_TotalPembayaranCard> {
  bool _terbuka = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final nominal = order.harga ?? order.hargaUsulan ?? 12000;

    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Pembayaran',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EA),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: Color(0xFF00880C),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Midtrans Snap',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00880C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatRupiah(nominal),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF3F4F6), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 15,
                    color: Color(0xFF00AA13),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Pembayaran Resmi & Aman',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _terbuka = !_terbuka),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      const Text(
                        'Rincian',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF00880C),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _terbuka
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: const Color(0xFF00880C),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_terbuka) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF3F4F6), height: 1),
            const SizedBox(height: 10),
            _BarisRincianHarga(
              label: 'Tarif Dasar Layanan',
              nilai: formatRupiah(nominal),
            ),
            const SizedBox(height: 6),
            const _BarisRincianHarga(
              label: 'Biaya Platform Layanan',
              nilai: 'Rp 2.000',
              dicoret: true,
            ),
            const SizedBox(height: 6),
            const _BarisRincianHarga(
              label: 'Subsidi Mahasiswa UPNVJ',
              nilai: '-Rp 2.000',
              warnaNilai: Color(0xFF00AA13),
              tebalNilai: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _BarisRincianHarga extends StatelessWidget {
  const _BarisRincianHarga({
    required this.label,
    required this.nilai,
    this.dicoret = false,
    this.tebalNilai = false,
    this.warnaNilai,
  });

  final String label;
  final String nilai;
  final bool dicoret;
  final bool tebalNilai;
  final Color? warnaNilai;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        Text(
          nilai,
          style: TextStyle(
            fontSize: 12,
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

class _RincianPerjalananCard extends StatelessWidget {
  const _RincianPerjalananCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final jarakText = order.jarakKm != null
        ? '${order.jarakKm!.toStringAsFixed(1)} km'
        : '3.5 km';
    final durasiText = order.estimasiDurasi != null
        ? '±${order.estimasiDurasi!.inMinutes} mnt'
        : '±12 mnt';

    final namaJemput = order.alamatJemput != null &&
            order.alamatJemput!.contains(',')
        ? order.alamatJemput!.split(',').first.trim()
        : (order.alamatJemput ?? 'Indomaret RS Fatmawati');
    final detailJemput = order.alamatJemput ??
        'Jalan RS Fatmawati No. 04, Cilandak Barat, Jakarta Selatan';

    final namaTujuan = order.alamatTujuan != null &&
            order.alamatTujuan!.contains(',')
        ? order.alamatTujuan!.split(',').first.trim()
        : (order.alamatTujuan ?? 'UPN Veteran Jakarta (Gedung Wahidin)');
    final detailTujuan = order.alamatTujuan ??
        'Kampus Limo, Jl. Cinere Raya, Cinere, Depok, Jawa Barat';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Rincian Perjalanan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.route_outlined,
                    size: 13,
                    color: Color(0xFF4B5563),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$jarakText • $durasiText',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
              // TITIK JEMPUT
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.radio_button_checked_rounded,
                      size: 16,
                      color: Color(0xFF00AA13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Titik Jemput',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
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
                        if (order.deskripsi != null &&
                            order.deskripsi!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8EA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.edit_note_rounded,
                                  size: 15,
                                  color: Color(0xFF00880C),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    order.deskripsi!,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF00880C),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // CONNECTOR LINE
              const Padding(
                padding: EdgeInsets.only(left: 7),
                child: SizedBox(
                  height: 24,
                  child: VerticalDivider(
                    color: Color(0xFFE5E7EB),
                    thickness: 2,
                  ),
                ),
              ),

              // TUJUAN ANTAR
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tujuan Antar',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
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
            ],
          ),
        ),
      ],
    );
  }
}

class _BilahBayarAloha extends StatelessWidget {
  const _BilahBayarAloha({required this.order});

  final Order order;

  void _bukaMenuOpsi(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xFF4B5563)),
                title: const Text('Salin Kode Pesanan'),
                subtitle: Text('#${order.kodeOrder}'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: order.kodeOrder));
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kode #${order.kodeOrder} disalin.')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.headset_mic_outlined,
                    color: Color(0xFF2563EB)),
                title: const Text('Pusat Bantuan Kampus 24/7'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push(Rute.pusatBantuan);
                },
              ),
              const Divider(color: Color(0xFFF3F4F6)),
              ListTile(
                leading: const Icon(Icons.cancel_outlined,
                    color: Color(0xFFDC2626)),
                title: const Text(
                  'Batalkan Pesanan',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text('Pesanan belum dibayar dapat langsung dibatalkan'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _konfirmasiBatal(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _konfirmasiBatal(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan Pesanan?'),
        content: Text(
          'Pesanan #${order.kodeOrder} yang belum dibayar akan langsung dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Jangan'),
          ),
          Consumer(
            builder: (ctx, ref, _) => FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop(true);
                try {
                  final key = buatIdempotencyKey();
                  await ref
                      .read(orderRepositoryProvider)
                      .batalkanOrder(order.id, idempotencyKey: key);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Order #${order.kodeOrder} dibatalkan.'),
                      ),
                    );
                  }
                } catch (galat) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          galat is GalatApi
                              ? galat.pesan
                              : 'Order gagal dibatalkan.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Ya, Batalkan'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nominal = order.harga ?? order.hargaUsulan ?? 12000;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Tombol Overflow (...)
            InkWell(
              onTap: () => _bukaMenuOpsi(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xFF4B5563),
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Tombol Bayar Sekarang Pill Penuh
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00AA13),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  onPressed: () => context.push(Rute.bayar(order.id)),
                  child: Row(
                    children: [
                      const Text(
                        'Bayar Sekarang',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatRupiah(nominal),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BilahPesanLagiAloha extends StatelessWidget {
  const _BilahPesanLagiAloha({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00AA13),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            onPressed: () => bukaFormOrder(context, order.serviceType, contoh: order),
            icon: const Icon(Icons.repeat_rounded, size: 18),
            label: const Text(
              'Pesan Lagi',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _JalanBatal extends ConsumerStatefulWidget {
  const _JalanBatal({required this.order});

  final Order order;

  @override
  ConsumerState<_JalanBatal> createState() => _JalanBatalState();
}

class _JalanBatalState extends ConsumerState<_JalanBatal> {
  bool _sedangMembatalkan = false;
  String? _idempotencyKey;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final skema = Theme.of(context).colorScheme;

    if (!order.status.isAktif) return const SizedBox.shrink();

    if (order.mintaBatalPada != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.hourglass_top_outlined,
            size: 18,
            color: skema.onSurfaceVariant,
          ),
          const SizedBox(width: AppTheme.spasiKecil),
          Expanded(
            child: Text(
              'Permintaan pembatalanmu sudah sampai ke admin, tinggal menunggu '
              'jawabannya. Jawabannya muncul di chat order ini.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: skema.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    if (order.dibayarPada != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: skema.onSurfaceVariant),
              const SizedBox(width: AppTheme.spasiKecil),
              Expanded(
                child: Text(
                  'Order yang sudah dibayar tidak bisa dibatalkan sendiri, karena '
                  'ada uang yang harus kembali. Admin yang memutuskan.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Center(
            child: TextButton(
              onPressed: _sedangMembatalkan ? null : _tanyaLaluMintaBatal,
              child: _sedangMembatalkan
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Minta pembatalan'),
            ),
          ),
        ],
      );
    }

    return Center(
      child: TextButton(
        onPressed: _sedangMembatalkan ? null : _tanyaLaluBatalkan,
        child: _sedangMembatalkan
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                'Batalkan order',
                style: TextStyle(color: Color(0xFFDC2626)),
              ),
      ),
    );
  }

  Future<void> _tanyaLaluMintaBatal() async {
    final order = widget.order;
    final alasan = await showDialog<String>(
      context: context,
      builder: (context) => const _DialogMintaBatal(),
    );

    if (alasan == null || !mounted) return;

    setState(() => _sedangMembatalkan = true);
    try {
      final key = _idempotencyKey ??= buatIdempotencyKey();
      await ref.read(orderRepositoryProvider).mintaBatalOrder(
            orderId: order.id,
            alasan: alasan,
            idempotencyKey: key,
          );
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMembatalkan = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi
                  ? galat.pesan
                  : 'Permintaan pembatalan gagal dikirim.',
            ),
          ),
        );
      return;
    }

    if (!mounted) return;
    setState(() => _sedangMembatalkan = false);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Permintaan pembatalan dikirim. Admin akan segera menjawab.',
          ),
        ),
      );
  }

  Future<void> _tanyaLaluBatalkan() async {
    final order = widget.order;
    final jadi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan order?'),
        content: Text('Order ${order.kodeOrder} yang belum dibayar akan dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Jangan'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Batalkan order',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );

    if (jadi != true || !mounted) return;

    setState(() => _sedangMembatalkan = true);
    try {
      final key = _idempotencyKey ??= buatIdempotencyKey();
      await ref
          .read(orderRepositoryProvider)
          .batalkanOrder(order.id, idempotencyKey: key);
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMembatalkan = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              galat is GalatApi ? galat.pesan : 'Order gagal dibatalkan.',
            ),
          ),
        );
      return;
    }

    if (!mounted) return;
    setState(() => _sedangMembatalkan = false);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Order ${order.kodeOrder} dibatalkan.')),
      );
  }
}

class _DialogMintaBatal extends StatefulWidget {
  const _DialogMintaBatal();

  @override
  State<_DialogMintaBatal> createState() => _DialogMintaBatalState();
}

class _DialogMintaBatalState extends State<_DialogMintaBatal> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Minta pembatalan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin yang memutuskan, karena ada uang yang harus kembali. Sampai '
            'dijawab, ordernya tetap berjalan. Tulis alasanmu; kalimat ini yang '
            'dibaca admin di chat ordermu.',
          ),
          const SizedBox(height: AppTheme.spasiSedang),
          TextField(
            controller: _controller,
            maxLength: BatasMasukan.pesanChat,
            autofocus: true,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Acaranya batal, jadi tidak jadi dipakai.',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Jangan'),
        ),
        TextButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Kirim permintaan'),
        ),
      ],
    );
  }
}
