import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/order.dart';
import '../../domain/service_catalog.dart';
import '../../providers/repository_providers.dart';

/// Layar sementara untuk memastikan fondasi tersambung: tema, Riverpod,
/// repository palsu, dan pemformatan rupiah/waktu.
///
/// Layar ini akan diganti Beranda Klien yang sesungguhnya di langkah
/// berikutnya. Jangan bangun fitur di atasnya.
class FondasiScreen extends ConsumerWidget {
  const FondasiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userAktifProvider).value;
    final repo = ref.watch(orderRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('UPNVJ Suruh')),
      body: StreamBuilder<List<Order>>(
        stream: user == null ? const Stream.empty() : repo.watchOrderKlien(user.id),
        builder: (context, snapshot) {
          if (user == null || !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppTheme.spasiSedang),
            children: [
              Text(
                'Halo, ${user.nama}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Peran: ${user.roles.map((r) => r.label).join(", ")}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.spasiBesar),
              Text(
                'Order contoh (${orders.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spasiKecil),
              for (final order in orders) _BarisOrder(order: order),
              const SizedBox(height: AppTheme.spasiBesar),
              Text(
                'Katalog layanan (${serviceCatalog.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spasiKecil),
              Wrap(
                spacing: AppTheme.spasiKecil,
                runSpacing: AppTheme.spasiKecil,
                children: [
                  for (final layanan in serviceCatalog)
                    Chip(
                      avatar: Icon(layanan.icon, size: 18),
                      label: Text(layanan.nama),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BarisOrder extends StatelessWidget {
  const _BarisOrder({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
      child: Card(
        child: ListTile(
          leading: Icon(serviceInfoOf(order.serviceType).icon),
          title: Text(serviceInfoOf(order.serviceType).nama),
          subtitle: Text(
            '${order.kodeOrder} · ${formatWaktuRelatif(order.dibuatPada)} · '
            '${formatRupiah(order.harga)}',
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: order.status.warnaLatar(skema),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              order.status.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: order.status.warnaTeks(skema),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
