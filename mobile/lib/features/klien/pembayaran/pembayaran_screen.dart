import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/format/formatters.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/transaksi_pembayaran.dart';
import '../../../domain/service_catalog.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/payment_providers.dart';
import 'widgets/panel_simulator.dart';

/// Layar pembayaran QRIS.
///
/// Klien tidak punya cara apa pun untuk menyatakan dirinya sudah membayar,
/// tidak ada tombol "saya sudah transfer", tidak ada unggah bukti. Tangkapan
/// layar bukan bukti yang sah (rencana capstone bagian 6); satu-satunya yang
/// boleh mengubah status adalah kabar dari gateway.
class PembayaranScreen extends ConsumerWidget {
  const PembayaranScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaksi = ref.watch(transaksiOrderProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: transaksi.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (galat, _) => _Pesan(
          ikon: Icons.error_outline,
          judul: 'Pembayaran tidak bisa dimulai',
          keterangan: '$galat',
        ),
        data: (transaksi) => switch (transaksi.status) {
          _ when transaksi.berhasil => _Berhasil(
            transaksi: transaksi,
            orderId: orderId,
          ),
          _ when transaksi.menunggu => _MenungguBayar(
            transaksi: transaksi,
            orderId: orderId,
          ),
          _ => _Pesan(
            ikon: Icons.timer_off_outlined,
            judul: 'Pembayaran kedaluwarsa',
            keterangan:
                'Batas waktu bayar sudah lewat. Buat ulang untuk mendapat '
                'kode QR baru.',
            aksi: FilledButton(
              onPressed: () => ref.invalidate(transaksiOrderProvider(orderId)),
              child: const Text('Buat Ulang'),
            ),
          ),
        },
      ),
    );
  }
}

class _MenungguBayar extends ConsumerWidget {
  const _MenungguBayar({required this.transaksi, required this.orderId});

  final TransaksiPembayaran transaksi;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final simulator = ref.watch(simulatorPembayaranProvider);
    final order = ref.watch(orderProvider(orderId)).value;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      children: [
        Center(
          child: Column(
            children: [
              Text(
                'Bayar dengan QRIS',
                style: teks.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              // Order mana yang sedang dibayar.
              //
              // Sebelumnya layar ini cuma menyebut angkanya. Klien yang punya
              // dua order menunggu bayar tidak punya satu pun cara memastikan
              // ia sedang membayar yang mana, dan angka yang kebetulan sama
              // membuat keliru itu mustahil disadari.
              if (order?.kodeOrder case final kode?) ...[
                const SizedBox(height: 2),
                Text(
                  order?.serviceType == null
                      ? kode
                      : '$kode · ${serviceInfoOf(order!.serviceType).nama}',
                  style: teks.bodySmall?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spasiKecil),
              Text(
                formatRupiah(transaksi.jumlah),
                style: teks.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: skema.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spasiBesar),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spasiBesar),
            child: Center(
              // Latar putihnya wajib: kode QR menuntut kontras dan zona sunyi
              // terang untuk bisa dipindai, jadi ia tidak boleh ikut menggelap
              // di tema gelap. Yang bisa diperbaiki cuma bentuknya, dan sudut
              // membulat membuat bidang putih itu terbaca sebagai plat yang
              // memang ditaruh di situ alih-alih lubang di tengah kartu.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
                child: QrImageView(
                  // Identitas QR mengikuti transaksinya, bukan layarnya: kalau
                  // transaksi berganti, Flutter tahu gambarnya harus diganti.
                  key: ValueKey('qris-${transaksi.id}'),
                  data: transaksi.qrisPayload,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(AppTheme.spasiSedang),
                  semanticsLabel: 'Kode QR pembayaran',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spasiSedang),
        _HitungMundur(kedaluwarsaPada: transaksi.kedaluwarsaPada),
        const SizedBox(height: 4),
        Text(
          'Status berubah sendiri begitu gateway mengabarkan uangnya masuk. '
          'Tidak perlu mengirim bukti transfer.',
          textAlign: TextAlign.center,
          style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
        ),
        if (simulator != null) ...[
          const SizedBox(height: AppTheme.spasiBesar),
          // Bersumbu pada order, bukan pada id transaksi: yang ditandai lunas
          // adalah tagihan yang sedang berlaku untuk order ini, dan hanya
          // servernya yang tahu tagihan mana itu.
          PanelSimulator(onBayar: () => simulator(orderId)),
        ],
      ],
    );
  }
}

/// Sisa waktu membayar, berdetak.
///
/// Sebelumnya layar ini cuma menyebut jam kedaluwarsanya. Itu memaksa orang
/// menghitung sendiri berapa lama lagi ia punya waktu, tepat pada saat ia sedang
/// berpindah ke aplikasi bank dan paling tidak punya perhatian untuk berhitung.
/// Jamnya tetap disebut di bawah, karena yang beralih aplikasi butuh patokan
/// yang tidak ikut berubah.
///
/// Pewaktunya dimatikan di dispose. Pewaktu yang tertinggal hidup setelah
/// layarnya ditutup akan terus membangunkan widget yang sudah tidak ada.
class _HitungMundur extends StatefulWidget {
  const _HitungMundur({required this.kedaluwarsaPada});

  final DateTime kedaluwarsaPada;

  @override
  State<_HitungMundur> createState() => _HitungMundurState();
}

class _HitungMundurState extends State<_HitungMundur> {
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
      // Berhenti sendiri di nol. Yang mengubah keadaan layar ini bukan pewaktu
      // melainkan kabar dari gateway, jadi menghitung terus ke angka negatif
      // cuma membakar bingkai tanpa memberi tahu apa pun.
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
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;
    final habis = _sisa == Duration.zero;

    // Merah hanya di menit terakhir. Hitung mundur yang merah sejak awal membuat
    // orang terburu-buru selama tiga puluh menit penuh, dan warna yang selalu
    // mendesak berhenti terbaca sebagai desakan.
    final mendesak = _sisa.inMinutes < 1;

    final menit = _sisa.inMinutes.toString().padLeft(2, '0');
    final detik = _sisa.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Column(
      children: [
        Text(
          habis ? 'Waktu bayar habis' : 'Sisa waktu $menit:$detik',
          textAlign: TextAlign.center,
          style: teks.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: habis || mendesak ? skema.error : skema.onSurface,
          ),
        ),
        if (!habis)
          Text(
            'Bayar sebelum ${formatJam(widget.kedaluwarsaPada)}',
            textAlign: TextAlign.center,
            style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _Berhasil extends StatelessWidget {
  const _Berhasil({required this.transaksi, required this.orderId});

  final TransaksiPembayaran transaksi;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return _Pesan(
      ikon: Icons.check_rounded,
      // Cakram hijau berisi, bukan ikon bergaris.
      //
      // Ini beat paling positif di seluruh alur klien: uangnya sudah pindah dan
      // pekerjaannya sudah berjalan. Ikon bergaris tipis menyampaikan itu dengan
      // nada yang sama seperti pemberitahuan apa pun, dan momen yang pantas
      // diyakinkan jadi terbaca ragu-ragu.
      ikonBerisi: true,
      judul: 'Pembayaran diterima',
      // Jumlahnya diangkat keluar dari kalimat. Di layar tempat uang benar-benar
      // berpindah, angka yang berpindah adalah faktanya, bukan keterangan yang
      // diselipkan di tengah paragraf.
      sorotan: formatRupiah(transaksi.jumlah),
      keterangan: 'Ordermu langsung disiarkan ke runner yang tersedia.',
      aksi: FilledButton(
        onPressed: () => context.pushReplacement(Rute.detailOrder(orderId)),
        child: const Text('Lihat Order'),
      ),
    );
  }
}

class _Pesan extends StatelessWidget {
  const _Pesan({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    this.sorotan,
    this.ikonBerisi = false,
    this.aksi,
  });

  final IconData ikon;
  final String judul;

  /// Satu angka atau kata yang pantas dibaca lebih dulu daripada kalimatnya.
  final String? sorotan;

  /// Benar untuk kabar baik yang pantas diyakinkan, bukan sekadar diberitahukan.
  final bool ikonBerisi;

  final String keterangan;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiBesar),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ikonBerisi)
              Container(
                padding: const EdgeInsets.all(AppTheme.spasiSedang),
                decoration: BoxDecoration(
                  color: skema.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(ikon, size: 36, color: skema.onPrimary),
              )
            else
              Icon(ikon, size: 48, color: skema.primary),
            const SizedBox(height: AppTheme.spasiSedang),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (sorotan case final sorotanIni?) ...[
              const SizedBox(height: AppTheme.spasiKecil),
              Text(
                sorotanIni,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: skema.primary,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: skema.onSurfaceVariant),
            ),
            if (aksi != null) ...[
              const SizedBox(height: AppTheme.spasiBesar),
              // Selebar isinya, bukan selebar layar. Tombol yang membentang
              // penuh di tengah layar kosong terbaca sebagai formulir yang belum
              // selesai, bukan sebagai satu tawaran.
              IntrinsicWidth(child: aksi!),
            ],
          ],
        ),
      ),
    );
  }
}
