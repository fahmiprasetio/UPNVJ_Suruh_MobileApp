import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/api_auth_repository.dart';
import 'repository_providers.dart';

/// Kesiapan sesi: token sudah dimuat, dan kalau ada isinya, sudah ditanyakan ke
/// server siapa pemiliknya.
///
/// Dulu ini bagian dari `main()`, ditunggu sebelum `runApp` dipanggil sama
/// sekali. Itu berarti satu panggilan jaringan berdiri di antara membuka
/// aplikasi dan layar pertama yang tergambar, dan kalau panggilan itu lambat
/// atau servernya tidak menyala, yang terlihat cuma jendela browser kosong,
/// bahkan sebelum lencana pembuka sempat muncul.
///
/// Sekarang dipicu lewat `ref.read` di [main], berjalan berbarengan dengan
/// animasi pembuka, bukan menahannya. Layar pembuka menunggu future ini lewat
/// [PembukaScreen] sebelum menandai dirinya selesai, jadi urutan "sesi
/// dipulihkan dulu baru layar dalam terbuka" tetap benar, cuma penantiannya
/// sekarang ditemani lencana yang bergerak, bukan layar kosong.
final kesiapanSesiProvider = FutureProvider<void>((ref) async {
  final auth = ref.watch(authRepositoryProvider);
  if (auth is ApiAuthRepository) {
    await auth.pulihkanSesi();
  }
});

/// Penanda bahwa layar pembuka sudah selesai memainkan animasinya.
///
/// Bentuknya [ChangeNotifier], bukan `StateProvider`, karena satu-satunya yang
/// perlu tahu nilainya adalah `redirect` milik GoRouter, dan GoRouter menerima
/// [Listenable]. Kalau nilainya disimpan sebagai state Riverpod, `routerProvider`
/// harus mengamatinya, dan setiap perubahan akan membangun ulang seluruh GoRouter
/// beserta riwayat navigasinya. Router cukup dibuat sekali; yang berubah cukup
/// isi objek ini.
///
/// Nilainya sekali jalan: sekali `true`, selamanya `true` sampai aplikasi
/// dimulai ulang. Pembuka bukan layar yang boleh dikunjungi lagi.
class StatusPembuka extends ChangeNotifier {
  bool _selesai = false;

  bool get selesai => _selesai;

  void tandaiSelesai() {
    if (_selesai) return;
    _selesai = true;
    notifyListeners();
  }
}

final statusPembukaProvider = Provider<StatusPembuka>((ref) {
  final status = StatusPembuka();
  ref.onDispose(status.dispose);
  return status;
});
