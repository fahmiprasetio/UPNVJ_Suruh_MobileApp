import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Identitas proyek Firebase yang dipakai notifikasi push.
///
/// ## Kenapa lewat --dart-define, bukan google-services.json
///
/// Cara baku FlutterFire adalah menaruh `google-services.json` di dalam folder Android
/// beserta plugin Gradle yang membacanya. Tidak dipakai di sini, dan alasannya bukan selera:
/// plugin itu MENGGAGALKAN build kalau berkasnya tidak ada, jadi seluruh proyek ini akan
/// berhenti bisa dibangun oleh siapa pun yang belum punya proyek Firebase — termasuk CI,
/// yang tidak akan pernah punya. `Firebase.initializeApp(options: ...)` menerima nilai yang
/// sama persis tanpa berkas maupun plugin itu.
///
/// Polanya juga sudah dipakai di sini untuk hal yang sederajat: alamat backend diisi saat
/// build lewat `--dart-define` (lihat `KonfigurasiApi`), bukan ditulis mati di sumber.
///
/// ## Ini bukan rahasia
///
/// Keempat nilainya ikut tertanam di dalam setiap APK dan bisa dibaca siapa pun yang
/// membongkarnya; Firebase memang merancangnya begitu. Yang menjaga proyek Firebase adalah
/// kunci akun layanan di sisi server, yang tidak pernah ikut ke aplikasi. Karena itu keempat
/// nilai ini boleh ditulis di perintah build dan di dokumentasi, dan tetap tidak ditulis di
/// dalam sumber: yang salah bukan kerahasiaannya, melainkan build rilis yang diam-diam
/// bicara ke proyek Firebase milik mesin pengembang.
class KonfigurasiFirebase {
  const KonfigurasiFirebase._();

  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String senderId = String.fromEnvironment('FIREBASE_SENDER_ID');

  /// Benar kalau keempat nilainya terisi.
  ///
  /// Semuanya atau tidak sama sekali: Firebase menolak inisialisasi yang salah satunya
  /// kosong, dan aplikasi yang gagal menyala gara-gara satu nilai yang lupa diisi jauh lebih
  /// buruk daripada aplikasi yang berjalan tanpa notifikasi.
  static bool get lengkap => apakahLengkap(
    projectId: projectId,
    appId: appId,
    apiKey: apiKey,
    senderId: senderId,
  );

  /// Bentuk [lengkap] yang nilainya bisa disebutkan pemanggil.
  ///
  /// Keempat nilai di atas konstanta waktu-kompilasi, jadi tanpa pintu ini satu-satunya cara
  /// menguji aturan "semuanya atau tidak sama sekali" adalah menjalankan ulang seluruh tes
  /// dengan `--dart-define` yang berbeda. Alasannya sama persis dengan parameter `nilai` di
  /// `KonfigurasiApi.baca`.
  @visibleForTesting
  static bool apakahLengkap({
    required String projectId,
    required String appId,
    required String apiKey,
    required String senderId,
  }) =>
      projectId.isNotEmpty &&
      appId.isNotEmpty &&
      apiKey.isNotEmpty &&
      senderId.isNotEmpty;

  static const FirebaseOptions opsi = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
  );
}
