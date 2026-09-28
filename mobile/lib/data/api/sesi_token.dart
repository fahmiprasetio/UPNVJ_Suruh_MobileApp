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
  bool _penyimpananBermasalah = false;

  /// Token yang sedang berlaku, atau `null` kalau belum masuk.
  String? get nilai => _token;

  bool get adaSesi => _token != null;

  /// Benar jika penyimpanan aman gagal dibaca atau tidak dapat dinetralkan saat logout.
  ///
  /// Nilai ini tidak membuka kembali sesi. Ia hanya memberi UI alasan untuk memperingatkan
  /// pengguna bahwa perangkat tidak dapat menjamin token lama sudah hilang secara permanen.
  bool get penyimpananBermasalah => _penyimpananBermasalah;

  /// Memuat token yang tersimpan saat aplikasi mulai.
  ///
  /// Kegagalan membaca penyimpanan tidak dibiarkan menggagalkan aplikasi. Keystore bisa
  /// menolak membuka isinya setelah pengguna mengganti kunci layarnya atau memulihkan
  /// perangkat dari cadangan, dan akibat yang benar untuk itu adalah "silakan masuk
  /// lagi", bukan aplikasi yang tidak mau menyala sama sekali.
  Future<void> muat() async {
    try {
      final tersimpan = await _penyimpanan.read(key: _kunci);
      _token = tersimpan == null || tersimpan.isEmpty ? null : tersimpan;
      _penyimpananBermasalah = false;
    } catch (_) {
      _token = null;
      // Jangan membiarkan kegagalan baca yang mungkin sementara memulihkan token lama
      // pada peluncuran berikutnya. Upaya netralisasi tetap dilakukan, tetapi kegagalan
      // baca dicatat agar pengguna mendapat peringatan aman di layar masuk.
      await _netralkanPenyimpanan();
      _penyimpananBermasalah = true;
    }
  }

  Future<void> isi(String token) async {
    _token = token;
    try {
      await _penyimpanan.write(key: _kunci, value: token);
      _penyimpananBermasalah = false;
    } catch (_) {
      // Sesinya tetap berlaku untuk pemakaian sekarang, cuma tidak bertahan sampai
      // aplikasi dibuka lagi. Statusnya dicatat supaya kegagalan penyimpanan tidak
      // diam-diam dianggap berhasil.
      _penyimpananBermasalah = true;
    }
  }

  Future<void> kosongkan() async {
    // Memori selalu dibersihkan lebih dulu agar permintaan berikutnya tidak pernah
    // membawa token lama, sekalipun Keystore/Keychain sedang rusak.
    _token = null;
    _penyimpananBermasalah = !await _netralkanPenyimpanan();
  }

  /// Menimpa token sebelum menghapusnya memberi dua jalur menuju keadaan aman.
  ///
  /// Jika `delete` gagal tetapi `write` berhasil, peluncuran berikutnya hanya membaca
  /// string kosong yang diperlakukan sebagai tidak ada sesi. Jika `write` gagal tetapi
  /// `delete` berhasil, token juga sudah hilang. Hanya kegagalan keduanya yang berarti
  /// penyimpanan tidak dapat menjamin logout permanen.
  Future<bool> _netralkanPenyimpanan() async {
    var berhasil = false;

    try {
      await _penyimpanan.write(key: _kunci, value: '');
      berhasil = true;
    } catch (_) {
      // Tetap coba delete; salah satu operasi yang berhasil sudah cukup untuk
      // memastikan token lama tidak dapat dipulihkan.
    }

    try {
      await _penyimpanan.delete(key: _kunci);
      berhasil = true;
    } catch (_) {
      // Status aman ditentukan dari gabungan kedua upaya di atas.
    }

    return berhasil;
  }
}
