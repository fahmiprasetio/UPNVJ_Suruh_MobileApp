import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../domain/enums.dart';
import '../../providers/order_providers.dart';

/// Lonceng notifikasi di bilah atas beranda.
///
/// Membuka layar Kotak Masuk Notifikasi saat diketuk. Menampilkan lencana
/// jumlah pesanan yang membutuhkan tindakan pengguna (menunggu pembayaran,
/// persetujuan penawaran runner) atau memiliki pesan chat yang belum dibaca.
class TombolNotifikasi extends ConsumerWidget {
  const TombolNotifikasi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderKlienProvider);

    final jumlahPerhatian = orderAsync.maybeWhen(
      data: (halaman) => halaman.isi.where((o) =>
          o.status == OrderStatus.menungguPembayaran ||
          o.status == OrderStatus.menungguPersetujuanKlien ||
          o.jumlahPesanBelumDibaca > 0).length,
      orElse: () => 0,
    );

    final ikon = const Icon(Icons.notifications_outlined);

    return IconButton(
      onPressed: () => context.push(Rute.notifikasi),
      tooltip: 'Notifikasi',
      icon: jumlahPerhatian > 0
          ? Badge.count(
              count: jumlahPerhatian,
              child: ikon,
            )
          : ikon,
    );
  }
}
