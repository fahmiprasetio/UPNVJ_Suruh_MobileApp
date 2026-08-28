import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token sesi yang sedang berlaku.
///
/// Dibaca serentak lewat [nilai], tanpa `await`, karena setiap permintaan HTTP butuh
/// nilainya tepat saat header disusun. Menjadikannya `Future` berarti setiap permintaan
/// menunggu pembacaan penyimpanan lebih dulu, dan itu biaya yang dibayar berkali-kali
/// untuk nilai yang hampir tidak pernah berubah. Karena itu bentuknya begini: dibaca
/// sekali dari penyimpanan saat aplikasi mulai, disimpan di memori, dan penyimpanannya
/// ditulis di latar setiap kali nilainya berubah.
///
/// ## Kenapa Keystore, bukan SharedPreferences
///
/// Token adalah kunci akun. Siapa pun yang memegangnya adalah pemilik akun itu sampai
/// tokennya kedaluwarsa, tanpa perlu tahu nomor HP maupun kode masuknya. Menaruhnya di
/// berkas preferensi biasa berarti ia ikut terbaca aplikasi lain di perangkat yang sudah
/// di-root, dan ikut terbawa oleh cadangan otomatis ke tempat yang tidak diketahui
/// pemiliknya. `flutter_secure_storage` menaruhnya di Keystore (Android) dan Keychain
/// (iOS), tempat yang memang dibuat untuk ini. Setelan bawaannya sudah yang dituju:
/// isinya disandi AES-GCM dengan kunci yang dibungkus RSA di dalam Keystore.
///
/// ## Di web, ini bukan Keystore
///
/// Browser tidak punya Keystore. Di sana paketnya jatuh ke penyimpanan browser, dan itu
/// disebutkan di sini terus terang, bukan dianggap sama amannya. Aplikasi ini di browser
/// hanya dipakai saat mengembangkan; yang dikirim ke pengguna adalah build Android.
class SesiToken {
  SesiToken({FlutterSecureStorage? penyimpanan})
    : _penyimpanan = penyimpanan ?? const FlutterSecureStorage();

  static const String _kunci = 'sesi_token';

  final FlutterSecureStorage _penyimpanan;

  String? _token;

  /// Token yang sedang berlaku, atau `null` kalau belum masuk.
  String? get nilai => _token;

  bool get adaSesi => _token != null;

  /// Memuat token yang tersimpan saat aplikasi mulai.
  ///
  /// Kegagalan membaca penyimpanan tidak dibiarkan menggagalkan aplikasi. Keystore bisa
  /// menolak membuka isinya setelah pengguna mengganti kunci layarnya atau memulihkan
  /// perangkat dari cadangan, dan akibat yang benar untuk itu adalah "silakan masuk
  /// lagi", bukan aplikasi yang tidak mau menyala sama sekali.
  Future<void> muat() async {
    try {
      _token = await _penyimpanan.read(key: _kunci);
    } catch (_) {
      _token = null;
    }
  }

  Future<void> isi(String token) async {
    _token = token;
    try {
      await _penyimpanan.write(key: _kunci, value: token);
    } catch (_) {
      // Sesinya tetap berlaku untuk pemakaian sekarang, cuma tidak bertahan sampai
      // aplikasi dibuka lagi. Menggagalkan proses masuk karena ini berarti pengguna
      // tidak bisa masuk sama sekali di perangkat yang penyimpanan amannya bermasalah.
    }
  }

  Future<void> kosongkan() async {
    _token = null;
    try {
      await _penyimpanan.delete(key: _kunci);
    } catch (_) {
      // Sengaja ditelan, dengan alasan yang berbeda dari dua di atas: yang di memori
      // sudah dibuang, jadi aplikasi ini tidak akan memakainya lagi. Yang tertinggal
      // adalah salinan di penyimpanan yang akan ditimpa saat masuk berikutnya.
    }
  }
}
