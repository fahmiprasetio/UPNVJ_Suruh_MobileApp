import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Pilihan tema yang bertahan sampai aplikasi dibuka lagi.
///
/// Bawaannya [ThemeMode.light], bukan [ThemeMode.system]. Sistem ini dirancang
/// di tema terang: kertas nyaris putih, kartu putih, hijau dan maroon cuma
/// sebagai aksen. Mengikuti setelan perangkat berarti orang yang HP-nya
/// kebetulan sedang mode gelap tidak pernah melihat rupa yang dirancang itu,
/// dan yang ia nilai bukan pilihan siapa pun melainkan setelan yang sudah ada
/// di HP-nya sejak sebelum aplikasi ini dipasang. Gelap tetap ada, tapi sebagai
/// pilihan yang diambil sengaja lewat Pengaturan.
///
/// Bentuknya meniru [SesiToken]: dibaca sekali saat aplikasi mulai lalu
/// disimpan di memori, karena nilainya dibaca tiap kali aplikasi digambar
/// ulang dan hampir tidak pernah berubah.
class PreferensiTema {
  PreferensiTema({FlutterSecureStorage? penyimpanan})
    : _penyimpanan = penyimpanan ?? const FlutterSecureStorage();

  static const String _kunci = 'mode_tema';

  final FlutterSecureStorage _penyimpanan;

  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;

  /// Memuat pilihan yang tersimpan saat aplikasi mulai.
  ///
  /// Kegagalan membaca penyimpanan jatuh ke tema terang, bukan menggagalkan
  /// aplikasi: yang hilang cuma pilihan yang pernah dibuat, dan yang tersisa
  /// tetap tampilan yang bisa dipakai.
  Future<void> muat() async {
    try {
      _mode = _dariNama(await _penyimpanan.read(key: _kunci));
    } catch (_) {
      _mode = ThemeMode.light;
    }
  }

  Future<void> simpan(ThemeMode mode) async {
    _mode = mode;
    try {
      await _penyimpanan.write(key: _kunci, value: mode.name);
    } catch (_) {
      // Pilihannya tetap berlaku untuk pemakaian sekarang, cuma tidak bertahan
      // sampai aplikasi dibuka lagi.
    }
  }

  static ThemeMode _dariNama(String? nama) => ThemeMode.values.firstWhere(
    (mode) => mode.name == nama,
    orElse: () => ThemeMode.light,
  );
}
