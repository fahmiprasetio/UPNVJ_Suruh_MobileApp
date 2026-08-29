import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
