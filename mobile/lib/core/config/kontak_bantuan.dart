/// Kanal bantuan ke admin: nomor WhatsApp dan jam layanannya.
///
/// Dulu keduanya ditulis mati di layar Pusat Bantuan. Itu bukan keputusan kode: nomor dan
/// jam layanan adalah keputusan mitra, dan bisa berubah tanpa ada yang membangun ulang
/// aplikasi. Yang ditulis mati juga ikut terbawa ke build rilis siapa pun yang lupa
/// menggantinya, lalu pengguna menghubungi nomor yang salah tanpa ada yang tahu.
///
/// Sekarang nilainya diisi saat build lewat `--dart-define=NOMOR_BANTUAN=62812...` dan
/// `--dart-define=JAM_BANTUAN="setiap hari pukul 08.00 - 20.00 WIB"`, polanya sama dengan
/// `API_BASE_URL` dan `SUMBER_DATA`.
///
/// Dua aturan yang sengaja berbeda antara pengembangan dan rilis:
///
///   - Di mode debug, nomor dan jam yang dulu tertanam dipakai sebagai nilai bawaan, supaya
///     menjalankan aplikasi saat mengembangkan layar tidak menuntut menyebut keduanya setiap
///     kali.
///   - Di build rilis tanpa nomor, kanal bantuan dinyatakan TIDAK TERSEDIA dan layar
///     menyatakannya terus terang, bukan memasang nilai karangan. Aplikasi yang jujur bahwa
///     kanalnya belum ada lebih baik daripada aplikasi yang mengarahkan pengguna ke nomor
///     yang belum disetujui mitra.
///
/// Jam layanan tidak pernah dikarang: tanpa nilai, layar tidak menyebut jam apa pun.
class KontakBantuan {
  const KontakBantuan({this.noHpWhatsapp = '', this.jamLayanan = ''});

  /// Nomor dalam format internasional tanpa tanda plus (mis. `6281290001958`), bentuk yang
  /// diminta tautan `wa.me`. Kosong kalau belum tersedia.
  final String noHpWhatsapp;

  /// Kalimat jam layanan yang siap ditampilkan. Kosong kalau tidak diketahui.
  final String jamLayanan;

  bool get tersedia => noHpWhatsapp.isNotEmpty;
  bool get punyaJamLayanan => jamLayanan.isNotEmpty;

  static const KontakBantuan tidakTersedia = KontakBantuan();

  /// Nilai pengembangan, yang dulu tertanam di layar. Hanya dipakai di mode debug.
  static const KontakBantuan _pengembangan = KontakBantuan(
    noHpWhatsapp: '6281290001958',
    jamLayanan: 'setiap hari pukul 08.00 - 20.00 WIB',
  );

  static const String _noHpBuild = String.fromEnvironment('NOMOR_BANTUAN');
  static const String _jamBuild = String.fromEnvironment('JAM_BANTUAN');

  /// Menentukan kontak yang berlaku. [noHp] dan [jam] ada supaya aturannya bisa diuji tanpa
  /// membangun ulang dengan `--dart-define` yang berbeda; pemanggil biasa cukup mengisi
  /// [modeDebug].
  static KontakBantuan baca({
    required bool modeDebug,
    String noHp = _noHpBuild,
    String jam = _jamBuild,
  }) {
    final nomor = noHp.trim();
    if (nomor.isNotEmpty) {
      return KontakBantuan(noHpWhatsapp: nomor, jamLayanan: jam.trim());
    }
    return modeDebug ? _pengembangan : tidakTersedia;
  }
}
