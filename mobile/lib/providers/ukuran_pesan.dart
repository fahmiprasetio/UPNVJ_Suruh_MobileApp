import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/batas_halaman.dart';

/// Jendela pesan untuk tiap order yang chatnya pernah dibuka.
///
/// Bentuknya peta, bukan satu angka, karena jendelanya milik satu percakapan. Kalau
/// satu angka dipakai bersama, membuka chat order lain akan mewarisi jendela lebar
/// dari percakapan sebelumnya, dan yang terjadi bukan sekadar salah tampilan
/// melainkan permintaan yang mengambil jauh lebih banyak daripada yang dibutuhkan.
///
/// Order yang belum pernah disebut memakai [BatasHalaman.bawaan], jadi peta ini mulai
/// kosong dan cuma menyimpan yang benar-benar diperlebar orang.
class UkuranPesan extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  int untuk(String orderId) => state[orderId] ?? BatasHalaman.bawaan;

  bool bisaDiperbesar(String orderId) => untuk(orderId) < BatasHalaman.maksimal;

  void perbesar(String orderId) {
    if (!bisaDiperbesar(orderId)) return;

    // Peta baru, bukan yang lama disunting di tempat. Riverpod membandingkan keadaan
    // lama dengan yang baru untuk memutuskan siapa yang perlu dibangun ulang, dan peta
    // yang diubah di tempat sama dengan dirinya sendiri: tidak ada yang bangun.
    state = {
      ...state,
      orderId: (untuk(orderId) + BatasHalaman.tambahan).clamp(
        0,
        BatasHalaman.maksimal,
      ),
    };
  }
}

final ukuranPesanProvider = NotifierProvider<UkuranPesan, Map<String, int>>(
  UkuranPesan.new,
);
