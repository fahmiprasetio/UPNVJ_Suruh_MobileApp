import '../config/sumber_data.dart';

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

  /// Alamat yang boleh dipakai, atau lemparan kalau alamatnya tidak pantas untuk
  /// build ini.
  ///
  /// Nilai bawaannya alamat emulator lewat http biasa, dan itu benar untuk mesin
  /// pengembang. Yang berbahaya adalah build rilis yang lahir tanpa
  /// `--dart-define=API_BASE_URL`: ia menyala seperti biasa, lalu setiap permintaan
  /// gagal karena Android memblokir lalu lintas tanpa sandi, dan yang terlihat
  /// pengguna cuma "tidak bisa menghubungi server" tanpa sebab yang bisa ditebak
  /// siapa pun. Aplikasi yang gagal menyala terang-terangan jauh lebih baik daripada
  /// aplikasi yang menyala menuju alamat yang salah.
  ///
  /// Alamat http juga ditolak di rilis walaupun servernya bisa dijangkau. Token sesi
  /// dan nomor HP orang tidak boleh berangkat tanpa sandi, dan alamat http yang
  /// kebetulan bekerja saat diuji adalah alamat yang akan terbawa ke tangan pengguna.
  ///
  /// Polanya sama persis dengan [KonfigurasiSumberData.baca], yang menolak data
  /// tiruan di build rilis. [nilai] ada supaya penolakannya bisa dibuktikan di tes:
  /// [baseUrl] konstanta waktu-kompilasi, jadi tanpa parameter ini satu-satunya cara
  /// mengujinya adalah menjalankan ulang seluruh tes dengan `--dart-define` berbeda,
  /// dan penolakan yang tidak pernah diuji baru ketahuan rusaknya saat dibutuhkan.
  static String baca({required bool modeDebug, String? nilai}) {
    final alamat = nilai ?? baseUrl;

    if (!modeDebug && !alamat.startsWith('https://')) {
      throw StateError(
        'API_BASE_URL="$alamat" tidak boleh dipakai di build rilis: '
        'alamat non-https mengirim token sesi dan nomor HP tanpa sandi, dan '
        'alamat bawaan menunjuk emulator di mesin pengembang. '
        'Isi lewat --dart-define=API_BASE_URL=https://...',
      );
    }

    return alamat;
  }

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
  /// Tetap dipakai sekalipun hub SignalR tersambung (`OrderHubClient`), sebagai
  /// jaring pengaman untuk koneksi hub yang putus sesaat. Yang berubah begitu hub
  /// tersambung cuma seberapa cepat perubahan orang lain terlihat, jedanya sendiri
  /// tetap dipertahankan.
  static const Duration jedaSegarkan = Duration(seconds: 15);

  /// Melengkapi alamat berkas yang dikirim server sebagai jalur relatif.
  ///
  /// Server menyebut foto bukti sebagai `/media/bukti/...`, bukan alamat lengkap, dan
  /// itu memang yang benar: server tidak selalu tahu lewat alamat mana ia dihubungi,
  /// dan alamat lengkap yang salah tebak akan tersimpan di basis data selamanya.
  /// Yang tahu ke mana ia sedang bicara adalah aplikasi ini.
  ///
  /// Alamat yang sudah lengkap dibiarkan apa adanya, termasuk `fake://` dari tiruan,
  /// supaya layar tetap bisa membedakan tautan sungguhan dari tautan karangan.
  static String lengkapi(String alamat) {
    if (!alamat.startsWith('/')) return alamat;
    return '$baseUrl$alamat';
  }
}
