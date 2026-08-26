import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/order.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/runner_providers.dart';
import '../../dev/pengalih_akun.dart';
import 'widgets/kartu_order_siaran.dart';

/// Layar utama runner: order yang sudah dibayar dan sedang mencari runner.
///
/// Semua runner melihat daftar yang sama pada saat yang sama, jadi dua orang
/// bisa menekan TERIMA untuk order yang sama dalam hitungan detik. Yang
/// menentukan siapa dapat bukan layar ini, melainkan repository, layar hanya
/// menyampaikan jawabannya (rencana capstone bagian 14.5).
class OrderMasukScreen extends ConsumerStatefulWidget {
  const OrderMasukScreen({super.key});

  @override
  ConsumerState<OrderMasukScreen> createState() => _OrderMasukScreenState();
}

class _OrderMasukScreenState extends ConsumerState<OrderMasukScreen> {
  /// Order yang tombolnya sedang menunggu jawaban. Disimpan per order, bukan
  /// satu bendera untuk seluruh layar, supaya menerima satu order tidak
  /// mengunci tombol order lain.
  final Set<String> _sedangDiproses = {};

  @override
  Widget build(BuildContext context) {
    final tersiar = ref.watch(orderTersiarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Masuk'),
        actions: const [PengalihAkun()],
      ),
      body: SafeArea(
        child: tersiar.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (galat, _) => _PesanKosong(
            ikon: Icons.error_outline,
            judul: 'Order gagal dimuat',
            keterangan: '$galat',
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return const _PesanKosong(
                ikon: Icons.inbox_outlined,
                judul: 'Belum ada order masuk',
                keterangan:
                    'Order yang sudah dibayar klien akan muncul di sini. '
                    'Siapa cepat, dia dapat.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppTheme.spasiSedang),
              itemCount: orders.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.spasiKecil),
              itemBuilder: (context, indeks) {
                final order = orders[indeks];
                return KartuOrderSiaran(
                  order: order,
                  sedangDiproses: _sedangDiproses.contains(order.id),
                  onTerima: () => _terima(order),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _terima(Order order) async {
    final user = ref.read(userAktifProvider).value;
    if (user == null) return;

    setState(() => _sedangDiproses.add(order.id));

    final bool dapat;
    try {
      dapat = await ref
          .read(orderRepositoryProvider)
          .terimaOrder(orderId: order.id, runnerId: user.id);
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangDiproses.remove(order.id));
      _kabari('Order ${order.kodeOrder} gagal diambil: $galat');
      return;
    }

    if (!mounted) return;
    setState(() => _sedangDiproses.remove(order.id));

    // Kalah cepat bukan kegagalan sistem, jadi tidak ditampilkan sebagai
    // galat. Ordernya juga hilang sendiri dari daftar karena siarannya sudah
    // ditutup, runner tidak perlu menyegarkan apa pun.
    _kabari(
      dapat
          ? 'Order ${order.kodeOrder} jadi milikmu. Segera kerjakan, ya.'
          : 'Order ${order.kodeOrder} keburu diambil runner lain.',
    );
  }

  void _kabari(String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
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
