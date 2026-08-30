import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/halaman.dart';
import '../domain/models/order.dart';
import 'ukuran_daftar.dart';
import 'repository_providers.dart';

/// Order milik klien yang sedang masuk, terbaru di atas, sebanyak jendela yang
/// sedang diminta.
///
/// Ikut [ukuranOrderKlienProvider], jadi menekan "muat lagi" membuat provider ini
/// dihitung ulang dengan jendela yang lebih lebar. Karena yang dihitung ulang adalah
/// provider yang sama, Riverpod menyimpan nilai sebelumnya selama pengambilan
/// berikutnya berjalan, dan layar bisa terus menampilkan daftar lamanya alih-alih
/// berkedip jadi pemuat.
final orderKlienProvider = StreamProvider<Halaman<Order>>((ref) {
  final user = ref.watch(userAktifProvider).value;
  if (user == null) return Stream.value(const Halaman<Order>.kosong());
  return ref
      .watch(orderRepositoryProvider)
      .watchOrderKlien(ukuran: ref.watch(ukuranOrderKlienProvider));
});

/// Satu order yang diamati terus-menerus.
///
/// Mengembalikan `null` kalau ordernya tidak ada, layar detail memakai ini
/// untuk membedakan "sedang dimuat" dari "memang tidak ada".
final orderProvider = StreamProvider.family<Order?, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).watchOrder(orderId);
});
