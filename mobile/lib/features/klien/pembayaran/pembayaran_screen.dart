import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/format/formatters.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/transaksi_pembayaran.dart';
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
              const SizedBox(height: 4),
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
        const SizedBox(height: AppTheme.spasiSedang),
        Text(
          'Bayar sebelum ${formatJam(transaksi.kedaluwarsaPada)}',
          textAlign: TextAlign.center,
          style: teks.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
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

class _Berhasil extends StatelessWidget {
  const _Berhasil({required this.transaksi, required this.orderId});

  final TransaksiPembayaran transaksi;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return _Pesan(
      ikon: Icons.check_circle_outline,
      judul: 'Pembayaran diterima',
      keterangan:
          '${formatRupiah(transaksi.jumlah)} sudah masuk. Ordermu langsung '
          'disiarkan ke runner yang tersedia.',
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
    this.aksi,
  });

  final IconData ikon;
  final String judul;
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
            Icon(ikon, size: 48, color: skema.primary),
            const SizedBox(height: AppTheme.spasiSedang),
            Text(judul, style: Theme.of(context).textTheme.titleMedium),
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
              aksi!,
            ],
          ],
        ),
      ),
    );
  }
}
