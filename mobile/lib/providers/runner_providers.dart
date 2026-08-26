import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/order.dart';
import 'repository_providers.dart';

/// Order yang sedang disiarkan ke semua runner.
///
/// Order yang sudah diambil runner ini sengaja dibuang dari daftar. Pada order
/// multi-runner (pindah kos butuh 3 orang) kuotanya bisa saja masih terbuka,
/// tapi menawarkan tombol TERIMA untuk order yang sudah dipegang sendiri cuma
/// mengundang salah tekan, dan repository memang akan menolaknya.
final orderTersiarProvider = StreamProvider<List<Order>>((ref) {
  final user = ref.watch(userAktifProvider).value;
  if (user == null) return Stream.value(const <Order>[]);
  return ref
      .watch(orderRepositoryProvider)
      .watchOrderTersiar()
      .map(
        (orders) =>
            orders.where((o) => !o.runnerIds.contains(user.id)).toList(),
      );
});

/// Order yang sedang dipegang runner yang masuk.
///
/// Belum punya layar sendiri, "Order Saya" sisi runner adalah langkah
/// berikutnya (rencana capstone bagian 15.9). Untuk sekarang dipakai layar
/// Order Masuk sebagai penanda berapa order yang sedang dipegang.
final orderRunnerProvider = StreamProvider<List<Order>>((ref) {
  final user = ref.watch(userAktifProvider).value;
  if (user == null) return Stream.value(const <Order>[]);
  return ref.watch(orderRepositoryProvider).watchOrderRunner(user.id);
});
