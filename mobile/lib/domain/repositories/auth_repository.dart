import '../models/app_user.dart';

/// Kontrak autentikasi.
///
/// Cara masuk akun (nomor HP + OTP, email, atau akun dibuatkan admin) masih
/// menunggu keputusan mitra, rencana capstone bagian 14.8 menandainya sebagai
/// pertanyaan pengunci. Karena itu kontrak ini sengaja dibuat minimal: apa pun
/// cara masuknya nanti, hasil akhirnya tetap satu [AppUser].
/// ## Aturan pemberian peran
///
/// Satu aturan yang tidak boleh dilanggar implementasi mana pun, termasuk API
/// .NET yang akan menggantikan tiruan ini:
///
/// **Pendaftaran mandiri selalu menghasilkan `{UserRole.klien}` saja. Peran
/// runner dan admin hanya boleh diberikan admin lewat dashboard web, tidak
/// pernah lewat aplikasi ini, dan tidak pernah atas permintaan sendiri.**
///
/// Alasannya bukan kerapian, melainkan siapa runner itu: runner adalah pegawai
/// mitra yang dipercaya masuk ke kos orang dan memegang uang belanja, bukan
/// peran yang bisa diambil siapa saja yang mengunduh aplikasi. Klien adalah
/// mahasiswa atau pelanggan. Kalau pendaftaran bisa menentukan perannya
/// sendiri, seluruh pemeriksaan peran di aplikasi ini kehilangan artinya,
/// karena penyerang tinggal meminta peran yang ia mau di langkah pertama.
///
/// Kontrak ini menegakkannya lewat bentuk, bukan lewat imbauan:
///
///   - [daftar] tidak punya parameter peran, jadi pemanggil tidak punya cara
///     menyebutkan peran yang ia inginkan.
///   - Tidak ada satu pun method di sini yang mengubah [AppUser.roles]. Bukan
///     kelupaan, memang tidak boleh ada. Pemberian peran adalah pekerjaan
///     dashboard admin (bagian 14.2), bukan pekerjaan aplikasi mobile.
///
/// Waktu API .NET ditulis, aturan yang sama berlaku di sana: DTO pendaftaran
/// tidak boleh punya field `roles` sama sekali. Field yang ada tapi diabaikan
/// tetap berbahaya, karena versi berikutnya bisa saja mulai membacanya.
abstract interface class AuthRepository {
  Stream<AppUser?> watchUserAktif();

  AppUser? get userAktif;

  Future<AppUser> masuk({required String noHp});

  /// Mendaftarkan akun baru. Selalu lahir sebagai klien, lihat aturan di atas.
  ///
  /// Tidak sekalian memasukkan penggunanya, karena di bentuk sungguhannya
  /// masih ada verifikasi di antara keduanya (OTP atau apa pun yang mitra
  /// pilih, bagian 14.8). Yang memutuskan seseorang sudah masuk tetap [masuk].
  Future<AppUser> daftar({required String nama, required String noHp});

  Future<void> keluar();
}
