import '../models/app_user.dart';

/// Kontrak autentikasi.
///
/// Masuk memakai nomor HP dan kode sekali pakai yang dikirim ke nomor itu. Bentuk
/// ini menyusul API .NET yang sudah menerapkannya, dan menggantikan kontrak lama
/// yang menerima nomor HP saja tanpa bukti apa pun.
///
/// ## Aturan pemberian peran
///
/// Satu aturan yang tidak boleh dilanggar implementasi mana pun:
///
/// **Pendaftaran mandiri selalu menghasilkan `{UserRole.klien}` saja. Peran runner
/// dan admin hanya boleh diberikan admin lewat dashboard web, tidak pernah lewat
/// aplikasi ini, dan tidak pernah atas permintaan sendiri.**
///
/// Alasannya bukan kerapian, melainkan siapa runner itu: runner adalah pegawai
/// mitra yang dipercaya masuk ke kos orang dan memegang uang belanja, bukan peran
/// yang bisa diambil siapa saja yang mengunduh aplikasi. Klien adalah mahasiswa atau
/// pelanggan. Kalau pendaftaran bisa menentukan perannya sendiri, seluruh pemeriksaan
/// peran di aplikasi ini kehilangan artinya, karena penyerang tinggal meminta peran
/// yang ia mau di langkah pertama.
///
/// Kontrak ini menegakkannya lewat bentuk, bukan lewat imbauan:
///
///   - [daftar] tidak punya parameter peran, jadi pemanggil tidak punya cara
///     menyebutkan peran yang ia inginkan.
///   - Tidak ada satu pun method di sini yang mengubah [AppUser.roles]. Bukan
///     kelupaan, memang tidak boleh ada. Pemberian peran adalah pekerjaan dashboard
///     admin (bagian 14.2), bukan pekerjaan aplikasi mobile.
///
/// Aturan yang sama sudah berlaku di API: DTO pendaftarannya tidak punya field
/// `roles` sama sekali, dan ada tes yang mengirimkannya untuk membuktikan diabaikan.
abstract interface class AuthRepository {
  Stream<AppUser?> watchUserAktif();

  AppUser? get userAktif;

  /// Mendaftarkan akun baru. Selalu lahir sebagai klien, lihat aturan di atas.
  ///
  /// Tidak sekalian memasukkan penggunanya, karena masih ada verifikasi di antara
  /// keduanya. Yang memutuskan seseorang sudah masuk tetap [masuk].
  Future<AppUser> daftar({required String nama, required String noHp});

  /// Meminta kode sekali pakai dikirim ke nomor tersebut.
  ///
  /// Berakhir sama saja untuk nomor yang terdaftar maupun tidak, dan itu bukan
  /// kelalaian: hasil yang berbeda mengubah langkah ini jadi alat memeriksa siapa
  /// saja yang punya akun, cukup dengan mencoba nomor satu per satu. Karena itu
  /// layar tidak boleh menyimpulkan apa pun tentang keberadaan akun dari sini.
  Future<void> mintaKode({required String noHp});

  /// Menukar kode yang benar dengan sesi.
  ///
  /// Kodenya sekali pakai dan berbatas waktu. Nomor yang tidak terdaftar dan kode
  /// yang salah gagal dengan cara yang sama persis, supaya tebakan yang meleset
  /// tidak memberi tahu bahwa setengah jawabannya sudah benar.
  Future<AppUser> masuk({required String noHp, required String kode});

  Future<void> keluar();
}
