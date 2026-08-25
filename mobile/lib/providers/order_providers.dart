import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/order.dart';
import 'repository_providers.dart';

/// Seluruh order milik klien yang sedang masuk, terbaru di atas.
final orderKlienProvider = StreamProvider<List<Order>>((ref) {
  final user = ref.watch(userAktifProvider).value;
  if (user == null) return Stream.value(const <Order>[]);
  return ref.watch(orderRepositoryProvider).watchOrderKlien(user.id);
});

/// Satu order yang diamati terus-menerus.
///
/// Mengembalikan `null` kalau ordernya tidak ada — layar detail memakai ini
/// untuk membedakan "sedang dimuat" dari "memang tidak ada".
final orderProvider = StreamProvider.family<Order?, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).watchOrder(orderId);
});
