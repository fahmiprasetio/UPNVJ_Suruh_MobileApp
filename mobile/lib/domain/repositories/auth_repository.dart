import '../models/app_user.dart';

/// Kontrak autentikasi.
///
/// Cara masuk akun (nomor HP + OTP, email, atau akun dibuatkan admin) masih
/// menunggu keputusan mitra, rencana capstone bagian 14.8 menandainya sebagai
/// pertanyaan pengunci. Karena itu kontrak ini sengaja dibuat minimal: apa pun
/// cara masuknya nanti, hasil akhirnya tetap satu [AppUser].
abstract interface class AuthRepository {
  Stream<AppUser?> watchUserAktif();

  AppUser? get userAktif;

  Future<AppUser> masuk({required String noHp});

  Future<void> keluar();
}
