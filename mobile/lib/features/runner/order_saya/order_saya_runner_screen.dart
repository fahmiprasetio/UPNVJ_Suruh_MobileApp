import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/order.dart';
import '../../../providers/runner_providers.dart';
import '../../dev/pengalih_akun.dart';
import 'widgets/kartu_order_runner.dart';
import 'widgets/lembar_selesaikan_order.dart';

/// Order yang dipegang runner, yang sedang dikerjakan dan yang sudah kelar.
///
/// Sebelum layar ini ada, order yang sudah diterima runner tidak punya
/// kelanjutan sama sekali: statusnya "Dikerjakan" selamanya karena tidak ada
/// tempat untuk menutupnya.
class OrderSayaRunnerScreen extends ConsumerWidget {
  const OrderSayaRunnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderRunnerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Saya'),
        actions: const [PengalihAkun()],
      ),
      body: SafeArea(
        child: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (galat, _) => _PesanKosong(
            ikon: Icons.error_outline,
            judul: 'Order gagal dimuat',
            keterangan: '$galat',
          ),
          data: (semua) {
            if (semua.isEmpty) {
              return const _PesanKosong(
                ikon: Icons.assignment_outlined,
                judul: 'Belum ada order yang kamu pegang',
                keterangan:
                    'Order yang kamu terima dari daftar Order Masuk akan '
                    'muncul di sini.',
              );
            }

            final dikerjakan = semua.where((o) => o.status.isAktif).toList();
            final selesai = semua.where((o) => !o.status.isAktif).toList();

            return ListView(
              padding: const EdgeInsets.all(AppTheme.spasiSedang),
              children: [
                if (dikerjakan.isNotEmpty)
                  ..._bagian(
                    context,
                    'Sedang dikerjakan',
                    dikerjakan,
                    onSelesaikan: (order) => _bukaLembarSelesai(context, order),
                  ),
                if (selesai.isNotEmpty)
                  ..._bagian(context, 'Sudah selesai', selesai),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _bagian(
    BuildContext context,
    String judul,
    List<Order> orders, {
    void Function(Order order)? onSelesaikan,
  }) {
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
          child: KartuOrderRunner(
            order: order,
            onSelesaikan: onSelesaikan == null
                ? null
                : () => onSelesaikan(order),
            onChat: () => context.push(Rute.chatOrderRunner(order.id)),
          ),
        ),
      const SizedBox(height: AppTheme.spasiSedang),
    ];
  }

  Future<void> _bukaLembarSelesai(BuildContext context, Order order) async {
    final ditutup = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => LembarSelesaikanOrder(order: order),
    );

    if (ditutup != true || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Order ${order.kodeOrder} ditandai selesai.')),
      );
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
