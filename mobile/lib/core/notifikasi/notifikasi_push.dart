import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../api/klien_api.dart';

/// Mendaftarkan perangkat ini ke server supaya ia bisa dikirimi notifikasi push, dan
/// melepasnya lagi saat penggunanya keluar.
///
/// ## Kenapa mengikuti status masuk, bukan dijalankan sekali saat aplikasi dibuka
///
/// Token perangkat menempel pada akun yang sedang masuk di sini, dan endpoint
/// pendaftarannya menuntut token sesi. Kalau pendaftarannya dijalankan sekali di awal, ia
/// berjalan sebelum ada yang masuk (ditolak 401), dan perangkat yang penggunanya berganti
/// akun tetap menerima notifikasi order milik pemilik sebelumnya. Persis pola yang sudah
/// dipakai koneksi hub SignalR (lihat `orderHubClientProvider`).
///
/// ## Yang sengaja belum ada
///
/// Ketukan pada notifikasinya tidak membuka layar order yang bersangkutan, cuma membuka
/// aplikasinya. Id ordernya sudah ikut di dalam muatan pesan (server mengirimkannya justru
/// untuk itu), jadi yang kurang tinggal pengarah rutenya. Ditunda dengan sengaja: ia butuh
/// keputusan rute yang berbeda untuk klien dan runner, dan seluruh perilakunya cuma bisa
/// dibuktikan di ponsel sungguhan, yang belum pernah terjadi (rencana capstone bagian 39.9).
///
/// Notifikasi juga tidak digambar ulang saat aplikasinya sedang dibuka dan terlihat. Android
/// memang tidak menampilkannya sendiri dalam keadaan itu, dan yang biasanya dipasang untuk
/// menutupinya adalah `flutter_local_notifications`. Tidak dipasang: layar yang sedang
/// terbuka sudah ikut berubah seketika lewat kabar SignalR, jadi yang ditambah paket itu
/// cuma pemberitahuan untuk perubahan yang sudah kelihatan di layar yang sedang ditatap
/// orangnya.
class NotifikasiPush {
  NotifikasiPush({
    required KlienApi klien,
    Future<bool> Function()? mintaIzin,
    Future<String?> Function()? ambilToken,
    Stream<String>? tokenBerganti,
  }) : _klien = klien,
       _mintaIzin = mintaIzin ?? _mintaIzinFirebase,
       _ambilToken = ambilToken ?? (() => FirebaseMessaging.instance.getToken()),
       // Fungsi, bukan aliran yang sudah jadi, dan bedanya bukan gaya: membaca
       // `FirebaseMessaging.instance` di sini berarti membacanya saat benda ini DIBUAT,
       // sedangkan pembuatannya terjadi saat aplikasi mulai. Kalau Firebase gagal menyala
       // (nilai buildnya salah, layanan Google Play tidak ada di perangkat itu), yang
       // terjadi bukan notifikasi yang mati melainkan aplikasi yang tidak mau terbuka sama
       // sekali. Dibungkus fungsi, seluruh sentuhan ke Firebase pindah ke dalam [mulai],
       // yang menelan galatnya.
       _tokenBerganti = tokenBerganti == null
           ? (() => FirebaseMessaging.instance.onTokenRefresh)
           : (() => tokenBerganti);

  final KlienApi _klien;
  final Future<bool> Function() _mintaIzin;
  final Future<String?> Function() _ambilToken;
  final Stream<String> Function() _tokenBerganti;

  StreamSubscription<String>? _langganan;
  String? _tokenTerdaftar;

  static Future<bool> _mintaIzinFirebase() async {
    final izin = await FirebaseMessaging.instance.requestPermission();
    return izin.authorizationStatus == AuthorizationStatus.authorized ||
        izin.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Meminta izin, lalu mendaftarkan token perangkat ini atas nama akun yang sedang masuk.
  ///
  /// Kegagalan apa pun ditelan. Perangkat yang gagal mendaftar kehilangan notifikasinya, dan
  /// itu memang kerugian, tapi melemparkan galat dari sini berarti aplikasi yang gagal
  /// dipakai sama sekali karena jaringan sedang buruk pada detik seseorang menekan masuk.
  Future<void> mulai() async {
    try {
      if (!await _mintaIzin()) return;

      final token = await _ambilToken();
      if (token == null || token.isEmpty) return;

      await _daftarkan(token);

      // Firebase memutar tokennya sendiri sesekali (pemulihan cadangan, pembersihan data,
      // pembaruan aplikasi). Tanpa langganan ini, perangkat berhenti menerima apa pun sejak
      // pemutaran pertama, tanpa satu tanda pun di layar siapa pun.
      _langganan ??= _tokenBerganti().listen(_daftarkan);
    } catch (_) {
      // Sengaja diam, alasannya di atas.
    }
  }

  /// Melepas perangkat ini, dipanggil saat penggunanya keluar.
  ///
  /// Dipanggil SEBELUM token sesinya dibuang tidak bisa dijamin dari sini, jadi kegagalannya
  /// ikut ditelan: yang paling buruk terjadi cuma satu baris perangkat yang tertinggal di
  /// server, dan baris itu akan berpindah sendiri ke pemiliknya yang baru begitu ada yang
  /// masuk lagi di perangkat ini.
  Future<void> berhenti() async {
    final token = _tokenTerdaftar;
    _tokenTerdaftar = null;

    await _langganan?.cancel();
    _langganan = null;

    if (token == null) return;

    try {
      await _klien.post('/api/perangkat/lepas', badan: {'token': token});
    } catch (_) {
      // Sengaja diam, alasannya di atas.
    }
  }

  Future<void> _daftarkan(String token) async {
    await _klien.post('/api/perangkat', badan: {'token': token});
    _tokenTerdaftar = token;
  }

  void dispose() {
    _langganan?.cancel();
    _langganan = null;
  }
}
