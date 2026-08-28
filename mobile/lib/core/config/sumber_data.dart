/// Dari mana aplikasi mengambil datanya.
///
/// Sampai sesi ini, jawabannya cuma satu dan ditulis mati di provider: tiruan.
/// Sekarang jawabannya dua, dan yang memilih adalah saklar build, bukan penyuntingan
/// kode. Bedanya penting: menukar backend dengan mengubah baris `return` berarti
/// setiap orang yang ingin menjalankan versi tiruan harus menyunting berkas yang
/// ikut ter-commit, dan cepat atau lambat suntingan itu terbawa ke `main`.
enum SumberData {
  /// Bicara ke API .NET yang sesungguhnya.
  api,

  /// Data karangan yang hidup di memori aplikasi.
  ///
  /// Ada dua alasan ini dipertahankan, bukan dihapus setelah API-nya jadi: layar
  /// bisa diuji tanpa menyalakan server dan basis data, dan aplikasi tetap bisa
  /// didemokan saat sidang kalau servernya sedang tidak hidup.
  tiruan,
}

/// Pembacaan saklar `--dart-define=SUMBER_DATA`.
class KonfigurasiSumberData {
  const KonfigurasiSumberData._();

  static const String pilihan = String.fromEnvironment(
    'SUMBER_DATA',
    defaultValue: 'api',
  );

  /// Menerjemahkan saklarnya, dan menolak yang tidak masuk akal.
  ///
  /// Dua penolakan, keduanya berupa lemparan, bukan nilai bawaan diam-diam:
  ///
  ///   - Nilai yang tidak dikenal (salah ketik `tiruann`) tidak boleh jatuh ke
  ///     salah satu pilihan. Jatuh ke `api` membuat orang mengira ia sedang
  ///     menguji tiruan padahal sedang menembak server; jatuh ke `tiruan`
  ///     membuat build rilis membawa data karangan.
  ///   - Tiruan di build rilis ditolak mentah-mentah. Di dalamnya ada pengalih
  ///     akun yang bisa menjadi siapa saja tanpa kode masuk, dan panel yang
  ///     menandai order mana pun lunas. Aplikasi yang gagal menyala terang-terangan
  ///     jauh lebih baik daripada aplikasi yang menyala dengan pintu itu terbuka.
  ///
  /// Pola yang sama sudah dipakai backend: servernya menolak menyala di luar
  /// Development kalau pengirim OTP sungguhan belum didaftarkan.
  /// [nilai] ada supaya penolakannya bisa dibuktikan di tes. [pilihan] adalah
  /// konstanta waktu-kompilasi, jadi tanpa parameter ini satu-satunya cara menguji
  /// nilai salah ketik adalah menjalankan ulang seluruh tes dengan `--dart-define`
  /// yang berbeda, dan penolakan yang tidak pernah diuji adalah penolakan yang
  /// baru ketahuan rusaknya saat dibutuhkan.
  static SumberData baca({required bool modeDebug, String? nilai}) {
    final dipilih = nilai ?? pilihan;
    final sumber = switch (dipilih) {
      'api' => SumberData.api,
      'tiruan' => SumberData.tiruan,
      _ => throw StateError(
        'SUMBER_DATA="$dipilih" tidak dikenal. Isi "api" atau "tiruan".',
      ),
    };

    if (sumber == SumberData.tiruan && !modeDebug) {
      throw StateError(
        'SUMBER_DATA=tiruan tidak boleh dipakai di build rilis: '
        'alat pengujinya bisa menjadi akun siapa saja dan menandai order lunas.',
      );
    }

    return sumber;
  }
}
