import '../models/pendapatan.dart';

/// Pendapatan runner yang sedang masuk.
///
/// Cuma satu method, dan cuma membaca, dengan alasan yang sama seperti
/// [TarifRepository]: yang mengubahnya (menandai bayaran sudah diserahkan)
/// adalah pekerjaan admin di dashboard web, bukan aplikasi ini. Kontrak yang
/// menyediakan `tandaiLunas` di sini akan mengundang layar yang memanggil
/// endpoint yang memang selalu dijawab 403 untuk token runner.
///
/// Tidak ada parameter id runner. Yang dibaca selalu milik pemegang token, dan
/// server memang tidak menyediakan bentuk permintaan lain; menyediakan
/// parameternya di sini berarti membuat orang percaya ada pilihan yang tidak ada.
abstract class PendapatanRepository {
  Future<Pendapatan> ambilPendapatan({int halaman = 1, int ukuran = 20});
}
