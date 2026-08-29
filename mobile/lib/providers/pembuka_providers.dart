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
/// animasi pembuka, bukan menahannya.
final kesiapanSesiProvider = FutureProvider<void>((ref) async {
  final auth = ref.watch(authRepositoryProvider);
  if (auth is ApiAuthRepository) {
    await auth.pulihkanSesi();
  }
});

/// Apakah lapisan pembuka sudah bubar dari atas aplikasi.
///
/// Sekali `true`, selamanya `true` sampai aplikasi dimulai ulang. Pembuka bukan
/// sesuatu yang boleh muncul kembali di tengah pemakaian.
///
/// Bentuknya state Riverpod biasa, bukan lagi [ChangeNotifier] yang dulu
/// dipasang sebagai `refreshListenable` GoRouter. Sejak pembuka menjadi lapisan
/// di atas aplikasi dan bukan rute tersendiri, router tidak perlu tahu apa-apa
/// tentangnya; yang perlu tahu cuma satu widget di [UpnvjSuruhApp] yang
/// memutuskan lapisannya masih dipasang atau tidak.
class StatusPembuka extends Notifier<bool> {
  @override
  bool build() => false;

  void tandaiSelesai() {
    if (state) return;
    state = true;
  }
}

final statusPembukaProvider = NotifierProvider<StatusPembuka, bool>(
  StatusPembuka.new,
);
