import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/halaman.dart';
import '../domain/models/order.dart';
import 'ukuran_daftar.dart';
import 'repository_providers.dart';

/// Order yang sedang disiarkan kepada runner yang sedang masuk.
///
/// Siarannya sudah tersaring di repository, jadi tidak ada penyaringan kedua
/// di sini. Order yang sudah dipegang runner ini dan order yang ia pesan
/// sendiri tidak pernah sampai, dan itu memang tempatnya: daftar yang cuma
/// dipangkas di tampilan tetap terkirim utuh ke perangkat.
final orderTersiarProvider = StreamProvider<Halaman<Order>>((ref) {
  final user = ref.watch(userAktifProvider).value;
  if (user == null) return Stream.value(const Halaman<Order>.kosong());
  return ref
      .watch(orderRepositoryProvider)
      .watchOrderTersiar(ukuran: ref.watch(ukuranOrderTersiarProvider));
});

/// Order yang sedang dipegang runner yang masuk.
///
/// Belum punya layar sendiri, "Order Saya" sisi runner adalah langkah
/// berikutnya (rencana capstone bagian 15.9). Untuk sekarang dipakai layar
/// Order Masuk sebagai penanda berapa order yang sedang dipegang.
final orderRunnerProvider = StreamProvider<Halaman<Order>>((ref) {
  final user = ref.watch(userAktifProvider).value;
  if (user == null) return Stream.value(const Halaman<Order>.kosong());
  return ref
      .watch(orderRepositoryProvider)
      .watchOrderRunner(ukuran: ref.watch(ukuranOrderRunnerProvider));
});

/// Order yang sedang ditawar runner yang masuk, dan tawarannya belum berakhir.
///
/// Daftar ketiga di sisi runner, dan bukan kemewahan: begitu ia menawar, ordernya
/// keluar dari [orderTersiarProvider] dan tidak pernah masuk [orderRunnerProvider],
/// yang isinya order yang sudah punya penugasan. Tanpa daftar ini penawaran yang
/// sudah dikirim lenyap dari pandangannya sepenuhnya.
final tawaranSayaProvider = StreamProvider<Halaman<Order>>((ref) {
  final user = ref.watch(userAktifProvider).value;
  if (user == null) return Stream.value(const Halaman<Order>.kosong());
  return ref
      .watch(orderRepositoryProvider)
      .watchTawaranSaya(ukuran: ref.watch(ukuranOrderRunnerProvider));
});
