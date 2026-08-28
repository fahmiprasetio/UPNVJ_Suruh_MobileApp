/// Alamat backend.
///
/// Diisi saat build lewat `--dart-define=API_BASE_URL=...`, bukan ditulis mati di
/// sini. Alasannya bukan kerapian: alamat server pengembangan yang ikut ter-commit
/// akan terbawa ke build rilis oleh siapa pun yang lupa menggantinya, dan aplikasi
/// yang diam-diam bicara ke server yang salah adalah kegagalan yang tidak terlihat
/// sampai ada yang memeriksa lalu lintasnya.
///
/// Nilai bawaannya sengaja alamat emulator Android, karena itu yang dipakai
/// sehari-hari saat mengembangkan. `10.0.2.2` adalah cara emulator menyebut
/// localhost mesin induknya; `localhost` di dalam emulator menunjuk emulator itu
/// sendiri, dan ini termasuk salah satu hal yang paling sering membuang waktu
/// orang yang baru menyambungkan aplikasi ke backend lokal.
class KonfigurasiApi {
  const KonfigurasiApi._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5059',
  );

  /// Batas sabar menunggu satu permintaan.
  ///
  /// Tanpa batas, permintaan yang tidak pernah dijawab akan menggantung layarnya
  /// selamanya dalam keadaan memuat, dan pengguna tidak punya cara keluar selain
  /// menutup paksa aplikasinya.
  static const Duration batasWaktu = Duration(seconds: 20);

  /// Selang pengambilan ulang untuk layar yang sedang terbuka.
  ///
  /// Jaring pengaman untuk perubahan yang dibuat orang lain, yang tidak terkabar
  /// ke aplikasi ini. Sengaja tidak terlalu rapat: pada layar order masuk, basi
  /// belasan detik cuma membuat runner menekan tombol yang gagal, sementara
  /// mengambil ulang tiap detik menguras baterai dan kuota sepanjang hari.
  ///
  /// Hilang begitu hub SignalR tersambung, karena sejak itu kabarnya datang tepat
  /// saat ada yang berubah.
  static const Duration jedaSegarkan = Duration(seconds: 15);
}
