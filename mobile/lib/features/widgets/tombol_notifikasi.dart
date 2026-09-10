import 'package:flutter/material.dart';

import '../klien/buka_form_order.dart' show belumTersedia;

/// Lonceng notifikasi di bilah atas beranda.
///
/// **Belum berfungsi.** Angka di pojoknya masih tetap, bukan jumlah
/// pemberitahuan yang sungguh menunggu, dan ketukannya menjawab "menyusul"
/// seperti pintu lain yang layarnya belum dibuat. Yang sudah nyata cuma
/// bentuk dan sambutannya saat disentuh kursor.
///
/// Ketukannya sengaja tidak dimatikan (`onPressed: null`): tombol mati tidak
/// menyambut kursor sama sekali, jadi mematikannya justru menghapus satu-satunya
/// bagian yang memang diminta ada lebih dulu.
class TombolNotifikasi extends StatelessWidget {
  const TombolNotifikasi({super.key});

  /// Sementara, sampai ada sumber pemberitahuan yang sungguhan.
  static const int _jumlahContoh = 3;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => belumTersedia(context, 'Notifikasi'),
      tooltip: 'Notifikasi',
      icon: Badge.count(
        count: _jumlahContoh,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
