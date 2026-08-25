import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/order.dart';
import '../../../providers/order_providers.dart';
import '../widgets/kartu_order_ringkas.dart';

/// Daftar order milik klien.
///
/// Dipisah jadi dua bagian karena keduanya dibaca dengan kebutuhan berbeda:
/// yang berjalan dipantau, yang sudah kelar dicari-cari.
class RiwayatOrderScreen extends ConsumerWidget {
  const RiwayatOrderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderKlienProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Order Saya')),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (galat, _) => _PesanKosong(
          ikon: Icons.error_outline,
          judul: 'Order gagal dimuat',
          keterangan: '$galat',
        ),
        data: (semua) {
          if (semua.isEmpty) {
            return const _PesanKosong(
              ikon: Icons.receipt_long_outlined,
              judul: 'Belum ada order',
              keterangan: 'Order yang kamu buat akan muncul di sini.',
            );
          }

          final berjalan = semua.where((o) => o.status.isAktif).toList();
          final selesai = semua.where((o) => !o.status.isAktif).toList();

          return ListView(
            padding: const EdgeInsets.all(AppTheme.spasiSedang),
            children: [
              if (berjalan.isNotEmpty)
                ..._bagian(context, 'Sedang berjalan', berjalan),
              if (selesai.isNotEmpty) ..._bagian(context, 'Sudah selesai', selesai),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _bagian(
    BuildContext context,
    String judul,
    List<Order> orders,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
        child: Text(
          '$judul (${orders.length})',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      for (final order in orders)
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
          child: KartuOrderRingkas(
            order: order,
            onTap: () => context.push(Rute.detailOrder(order.id)),
          ),
        ),
      const SizedBox(height: AppTheme.spasiSedang),
    ];
  }
}

class _PesanKosong extends StatelessWidget {
  const _PesanKosong({
    required this.ikon,
    required this.judul,
    required this.keterangan,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiBesar),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 44, color: skema.onSurfaceVariant),
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
          ],
        ),
      ),
    );
  }
}
