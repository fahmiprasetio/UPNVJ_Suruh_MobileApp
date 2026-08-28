import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/order.dart';
import 'repository_providers.dart';

/// Order yang sedang disiarkan kepada runner yang sedang masuk.
///
/// Siarannya sudah tersaring di repository, jadi tidak ada penyaringan kedua
/// di sini. Order yang sudah dipegang runner ini dan order yang ia pesan
/// sendiri tidak pernah sampai, dan itu memang tempatnya: daftar yang cuma
/// dipangkas di tampilan tetap terkirim utuh ke perangkat.
final orderTersiarProvider = StreamProvider<List<Order>>((ref) {
  final user = ref.watch(userAktifProvider).value;
  if (user == null) return Stream.value(const <Order>[]);
  return ref.watch(orderRepositoryProvider).watchOrderTersiar();
});

/// Order yang sedang dipegang runner yang masuk.
///
/// Belum punya layar sendiri, "Order Saya" sisi runner adalah langkah
/// berikutnya (rencana capstone bagian 15.9). Untuk sekarang dipakai layar
/// Order Masuk sebagai penanda berapa order yang sedang dipegang.
final orderRunnerProvider = StreamProvider<List<Order>>((ref) {
  final user = ref.watch(userAktifProvider).value;
  if (user == null) return Stream.value(const <Order>[]);
  return ref.watch(orderRepositoryProvider).watchOrderRunner();
});
