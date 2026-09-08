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
/// ## Ketukan notifikasi
///
/// Id order ikut di muatan pesan (kunci `orderId`, lihat `PengirimNotifikasiFirebase` di
/// backend), jadi ketukan -- baik saat aplikasi masih di latar belakang
/// (`onMessageOpenedApp`) maupun saat ia membuka aplikasi dari kondisi tertutup
/// (`getInitialMessage`) -- diteruskan lewat [bukaOrder]. Rute mana yang dituju (layar
/// klien atau layar runner) bukan urusan kelas ini; itu keputusan pemanggil, yang punya
/// akses ke peran aktif dan ke router.
///
/// ## Yang sengaja belum ada
///
/// Notifikasi tidak digambar ulang saat aplikasinya sedang dibuka dan terlihat. Android
/// memang tidak menampilkannya sendiri dalam keadaan itu, dan yang biasanya dipasang untuk
/// menutupinya adalah `flutter_local_notifications`. Tidak dipasang: layar yang sedang
/// terbuka sudah ikut berubah seketika lewat kabar SignalR, jadi yang ditambah paket itu
/// cuma pemberitahuan untuk perubahan yang sudah kelihatan di layar yang sedang ditatap
/// orangnya.
class NotifikasiPush {
  NotifikasiPush({
    required KlienApi klien,
    required void Function(String orderId) bukaOrder,
    Future<bool> Function()? mintaIzin,
    Future<String?> Function()? ambilToken,
    Stream<String>? tokenBerganti,
    Stream<RemoteMessage>? pesanDibuka,
    Future<RemoteMessage?> Function()? pesanAwal,
  }) : _klien = klien,
       _bukaOrder = bukaOrder,
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
           : (() => tokenBerganti),
       _pesanDibuka = pesanDibuka == null
           ? (() => FirebaseMessaging.onMessageOpenedApp)
           : (() => pesanDibuka),
       _pesanAwal = pesanAwal ?? (() => FirebaseMessaging.instance.getInitialMessage());

  final KlienApi _klien;
  final void Function(String orderId) _bukaOrder;
  final Future<bool> Function() _mintaIzin;
  final Future<String?> Function() _ambilToken;
  final Stream<String> Function() _tokenBerganti;
  final Stream<RemoteMessage> Function() _pesanDibuka;
  final Future<RemoteMessage?> Function() _pesanAwal;

  StreamSubscription<String>? _langganan;
  StreamSubscription<RemoteMessage>? _langgananPesan;
  String? _tokenTerdaftar;
  bool _awalDiperiksa = false;

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
      _langgananPesan ??= _pesanDibuka().listen(_tanganiPesan);

      // Cuma diperiksa sekali per proses: begitu dikonsumsi di sini, panggilan
      // berikutnya ke `getInitialMessage()` menjawab null juga, jadi tidak ada
      // gunanya diulang tiap kali `mulai()` dipanggil (mis. keluar-masuk akun
      // dalam satu proses yang sama).
      if (!_awalDiperiksa) {
        _awalDiperiksa = true;
        final awal = await _pesanAwal();
        if (awal != null) _tanganiPesan(awal);
      }
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
    await _langgananPesan?.cancel();
    _langgananPesan = null;

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

  void _tanganiPesan(RemoteMessage pesan) {
    final orderId = pesan.data['orderId'];
    if (orderId is String && orderId.isNotEmpty) _bukaOrder(orderId);
  }

  void dispose() {
    _langganan?.cancel();
    _langganan = null;
    _langgananPesan?.cancel();
    _langgananPesan = null;
  }
}
