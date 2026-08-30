/// Batas ukuran satu halaman daftar. Kembaran `BatasHalaman.cs` di server, dan
/// angkanya wajib sama: server menolak permintaan di atas [maksimal], jadi aplikasi
/// yang memakai angka lebih besar akan menerima galat 400 alih-alih daftar.
class BatasHalaman {
  const BatasHalaman._();

  /// Ukuran jendela saat sebuah daftar pertama kali dibuka.
  static const int bawaan = 20;

  /// Sebesar apa jendelanya bertambah setiap kali "muat lagi" ditekan.
  static const int tambahan = 20;

  /// Ukuran terbesar yang boleh diminta. Server menolak yang lebih dari ini.
  static const int maksimal = 100;
}
