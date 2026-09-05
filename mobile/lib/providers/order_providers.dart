import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/halaman.dart';
import '../domain/models/order.dart';
import 'ukuran_daftar.dart';
import 'ukuran_pesan.dart';
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
///
/// Selama ada yang mengamati, hub diminta mengikutkan koneksi ini ke grup order
/// tersebut. Itu yang membuat pesan chat baru dan perubahan status order muncul
/// seketika alih-alih menunggu pengambilan berkala lima belas detik: kabar apa pun
/// dari grup itu menabuh [ApiOrderRepository] untuk mengambil ulang. Diletakkan di
/// sini, bukan di masing-masing layar, karena setiap layar yang menampilkan satu
/// order (detail klien, chat kedua peran, layar bayar) sudah mengamati provider ini
/// — menaruhnya di layar berarti tiga tempat yang harus sama-sama ingat melepasnya.
final orderProvider = StreamProvider.family<Order?, String>((ref, orderId) {
  // Percakapannya ikut jendela order ini sendiri, bukan jendela bersama. Chat order
  // yang pernah diperlebar tidak boleh membuat chat order lain ikut mengambil jauh
  // lebih banyak daripada yang dibutuhkan.
  final ukuranPesan = ref.watch(ukuranPesanProvider.notifier).untuk(orderId);
  ref.watch(ukuranPesanProvider);

  // `null` di jalur data tiruan, yang memang tidak punya server untuk disambungi.
  final hub = ref.watch(orderHubClientProvider);
  hub?.ikutiOrder(orderId);
  ref.onDispose(() => hub?.berhentiIkutiOrder(orderId));

  return ref
      .watch(orderRepositoryProvider)
      .watchOrder(orderId, ukuranPesan: ukuranPesan);
});
