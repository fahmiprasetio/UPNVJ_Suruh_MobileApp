/// Token sesi yang sedang berlaku.
///
/// Dibaca serentak, tanpa `await`, karena setiap permintaan HTTP butuh nilainya
/// tepat saat header disusun. Menjadikannya `Future` berarti setiap permintaan
/// menunggu pembacaan penyimpanan lebih dulu, dan itu biaya yang dibayar berkali-kali
/// untuk nilai yang hampir tidak pernah berubah.
///
/// Untuk sekarang isinya hidup di memori proses saja, jadi menutup aplikasi berarti
/// masuk lagi. Menyimpannya supaya bertahan bukan sekadar menambah `SharedPreferences`:
/// token adalah kunci akun, jadi tempatnya Keystore atau Keychain, bukan berkas biasa
/// yang ikut terbaca aplikasi lain di perangkat yang sudah di-root. Itu langkah
/// tersendiri, dan bentuk kelas ini sudah disiapkan untuk menerimanya: yang berubah
/// nanti cuma isi [muat], [_tulis], dan [_hapus].
class SesiToken {
  String? _token;

  /// Token yang sedang berlaku, atau `null` kalau belum masuk.
  String? get nilai => _token;

  bool get adaSesi => _token != null;

  /// Memuat token yang tersimpan saat aplikasi mulai.
  ///
  /// Sekarang belum ada yang tersimpan, jadi selalu berakhir tanpa sesi. Dipanggil
  /// tetap, supaya tempat pemanggilannya sudah benar sebelum penyimpanannya ada.
  Future<void> muat() async {
    _token = null;
  }

  Future<void> isi(String token) async {
    _token = token;
    await _tulis(token);
  }

  Future<void> kosongkan() async {
    _token = null;
    await _hapus();
  }

  Future<void> _tulis(String token) async {}

  Future<void> _hapus() async {}
}
